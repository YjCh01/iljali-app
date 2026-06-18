import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:map/core/hiring/attendance_geofence_service.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/commission_chat_prompt_service.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/mutual_attendance_side_effects.dart';
import 'package:map/features/corporate/domain/services/commission_payer_resolver.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/work_category/domain/services/work_achievement_service.dart';
import 'package:map/features/attendance/domain/entities/check_in_method.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원·예정자·출근·수수료 — 기업/구직자 공유 로컬 저장 (MVP)
class LocalHiringRepository {
  LocalHiringRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyApplications = 'hiring_applications_v1';

  static Future<LocalHiringRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalHiringRepository(prefs);
    await repo._purgePersistedDemoApplications();
    return repo;
  }

  Future<List<HiringApplication>> fetchAll() async {
    final raw = _prefs.getString(_keyApplications);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => HiringApplication.fromJson(item.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }

  Future<List<HiringApplication>> fetchForSeeker(String email) async {
    final all = await fetchAll();
    return all.where((item) => item.seekerEmail == email).toList();
  }

  Future<List<HiringApplication>> fetchApplicantsForCorporate({
    String? companyKey,
  }) async {
    final all = await fetchAll();
    return all
        .where((item) =>
            item.status != HiringApplicationStatus.rejected &&
            (companyKey == null ||
                companyKey.isEmpty ||
                item.companyKey == null ||
                item.companyKey == companyKey))
        .toList();
  }

  Future<List<HiringApplication>> fetchScheduledForSeeker(String email) async {
    final all = await fetchForSeeker(email);
    return all
        .where((item) =>
            item.status == HiringApplicationStatus.scheduled ||
            item.status == HiringApplicationStatus.checkedIn ||
            item.status == HiringApplicationStatus.commissionPaid)
        .toList();
  }

  Future<List<HiringApplication>> fetchPendingCommissions() async {
    final all = await fetchAll();
    return all.where((item) => item.needsCommissionPayment).toList();
  }

  /// 결제 권한자 기준 미결제 수수료 (위임·본인 건)
  Future<List<HiringApplication>> fetchPendingCommissionsForPayer(
    String payerEmail,
  ) async {
    final pending = await fetchPendingCommissions();
    if (payerEmail.trim().isEmpty) return pending;

    final resolver = await _payerResolver();
    final normalized = payerEmail.trim().toLowerCase();
    final matched = <HiringApplication>[];
    for (final app in pending) {
      final resolved = await resolver.resolvePayerEmail(
        companyKey: app.companyKey,
        recruiterEmail: app.recruiterEmail,
      );
      if (resolved.trim().toLowerCase() == normalized) {
        matched.add(app);
      }
    }
    return matched;
  }

  Future<CommissionPayerResolver> _payerResolver() async {
    // Deferred import avoided — direct service
    return CommissionPayerResolver.create();
  }

  Future<bool> hasApplied(String postId, String seekerEmail) async {
    final all = await fetchForSeeker(seekerEmail);
    return all.any((item) =>
        item.postId == postId &&
        item.status != HiringApplicationStatus.rejected);
  }

  Future<HiringApplication> submitApplication({
    required String postId,
    required String postTitle,
    required String companyName,
    required String seekerEmail,
    required String seekerName,
    required String seekerPhoneMasked,
    required String workSchedule,
    String? companyKey,
    String? recruiterEmail,
    String? branchId,
    String? branchName,
    double? workplaceLatitude,
    double? workplaceLongitude,
    DateTime? suggestedWorkDate,
    String? hourlyWageText,
    JobEmploymentType employmentType = JobEmploymentType.daily,
    String? selectedShiftDate,
    String? shiftSlot,
    String? shuttleBookingId,
    String? preferredStopId,
  }) async {
    if (await hasApplied(postId, seekerEmail)) {
      throw StateError('already_applied');
    }

    final application = HiringApplication(
      id: 'app_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      postTitle: postTitle,
      companyName: companyName,
      seekerEmail: seekerEmail,
      seekerName: seekerName,
      seekerPhoneMasked: seekerPhoneMasked,
      appliedAt: DateTime.now(),
      status: HiringApplicationStatus.applied,
      workSchedule: workSchedule,
      employmentType: employmentType,
      workDate: suggestedWorkDate,
      companyKey: companyKey,
      recruiterEmail: recruiterEmail,
      branchId: branchId,
      branchName: branchName,
      workplaceLatitude: workplaceLatitude,
      workplaceLongitude: workplaceLongitude,
      commissionAmountKrw: employmentType == JobEmploymentType.daily
          ? (hourlyWageText != null
              ? CommissionCalculator.dailyWorkerFee()
              : CommissionCalculator.defaultKrw())
          : null,
      selectedShiftDate: selectedShiftDate,
      shiftSlot: shiftSlot,
      shuttleBookingId: shuttleBookingId,
      preferredStopId: preferredStopId,
    );

    await _upsert(application);
    HiringRefresh.markUpdated();
    return application;
  }

  Future<HiringApplication?> findById(String id) async {
    final all = await fetchAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> startChat(String applicationId) async {
    await _updateStatus(applicationId, HiringApplicationStatus.chatting);
  }

  Future<HiringApplication> instantAccept({
    required String applicationId,
    DateTime? workDate,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');

    final now = DateTime.now();
    final scheduled = existing.copyWith(
      status: HiringApplicationStatus.scheduled,
      workDate: workDate ??
          existing.workDate ??
          DateTime.now().add(const Duration(days: 1)),
      seekerWorkAgreedAt: existing.seekerWorkAgreedAt ?? now,
      employerWorkAgreedAt: existing.employerWorkAgreedAt ?? now,
    );
    await _upsert(scheduled);
    HiringRefresh.markUpdated();
    return scheduled;
  }

  /// 채팅 — 근무예정 합의 (쌍방)
  Future<HiringApplication> confirmWorkScheduleAgreement({
    required String applicationId,
    required bool asEmployer,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.status == HiringApplicationStatus.rejected ||
        existing.status == HiringApplicationStatus.noShow) {
      throw StateError('not_agreeable');
    }

    final now = DateTime.now();
    var updated = existing.copyWith(
      seekerWorkAgreedAt: asEmployer
          ? existing.seekerWorkAgreedAt
          : (existing.seekerWorkAgreedAt ?? now),
      employerWorkAgreedAt: asEmployer
          ? (existing.employerWorkAgreedAt ?? now)
          : existing.employerWorkAgreedAt,
    );

    if (updated.isWorkAgreementComplete &&
        updated.status == HiringApplicationStatus.applied) {
      updated = updated.copyWith(status: HiringApplicationStatus.chatting);
    }
    if (updated.isWorkAgreementComplete &&
        (updated.status == HiringApplicationStatus.chatting ||
            updated.status == HiringApplicationStatus.applied)) {
      updated = updated.copyWith(
        status: HiringApplicationStatus.scheduled,
        workDate: updated.workDate ?? DateTime.now().add(const Duration(days: 1)),
      );
    }

    await _upsert(updated);
    HiringRefresh.markUpdated();
    return updated;
  }

  /// 구인자 노쇼 확정 — 즉시 처리
  Future<HiringApplication> markNoShowByEmployer(String applicationId) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (!existing.isWorkAgreementComplete) {
      throw StateError('agreement_incomplete');
    }
    if (existing.status != HiringApplicationStatus.scheduled) {
      throw StateError('not_scheduled');
    }
    if (existing.isMutuallyConfirmed) {
      throw StateError('already_completed');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      status: HiringApplicationStatus.noShow,
      noShowMarkedAt: now,
    );
    await _upsert(updated);
    HiringRefresh.markUpdated();
    return updated;
  }

  Future<HiringApplication> checkIn(
    String applicationId, {
    double? latitude,
    double? longitude,
    CheckInMethod checkInMethod = CheckInMethod.gps,
    bool geofenceVerified = false,
    double? geofenceDistanceMeters,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.status != HiringApplicationStatus.scheduled) {
      throw StateError('not_scheduled');
    }
    if (existing.seekerCheckedIn) {
      throw StateError('already_checked_in');
    }

    if (existing.hasWorkplaceCoordinate &&
        !AttendanceGeofenceService.allowsRelaxedVerification &&
        !geofenceVerified) {
      throw StateError('geofence_failed');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      checkedInAt: now,
      checkInLatitude: latitude,
      checkInLongitude: longitude,
      checkInMethod: checkInMethod,
      seekerClockInVerifiedAt: geofenceVerified ? now : null,
      seekerGeofenceDistanceM: geofenceDistanceMeters,
    );
    final confirmed = _applyMutualConfirmation(updated, now: now);
    await _upsert(confirmed);
    if (!existing.isMutuallyConfirmed && confirmed.isMutuallyConfirmed) {
      await _handleMutualConfirmation(confirmed);
    }
    HiringRefresh.markUpdated();
    return confirmed;
  }

  /// QR 코드로 출근 기록
  Future<HiringApplication> checkInWithQr(
    String applicationId, {
    double? latitude,
    double? longitude,
    bool geofenceVerified = false,
    double? geofenceDistanceMeters,
  }) async {
    return checkIn(
      applicationId,
      latitude: latitude,
      longitude: longitude,
      checkInMethod: CheckInMethod.qr,
      geofenceVerified: geofenceVerified,
      geofenceDistanceMeters: geofenceDistanceMeters,
    );
  }

  Future<HiringApplication> approveApplication(String applicationId) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.status != HiringApplicationStatus.applied) {
      throw StateError('not_pending');
    }
    final updated = existing.copyWith(status: HiringApplicationStatus.chatting);
    await _upsert(updated);
    HiringRefresh.markUpdated();
    return updated;
  }

  /// 기업 출근 확인 — 구직자 선확인·기업 선확인 모두 지원 (지오펜스 필수)
  Future<HiringApplication> confirmEmployerAttendance(
    String applicationId, {
    double? latitude,
    double? longitude,
    bool geofenceVerified = false,
    double? geofenceDistanceMeters,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.status != HiringApplicationStatus.scheduled) {
      throw StateError('not_scheduled');
    }
    if (existing.isMutuallyConfirmed) {
      throw StateError('already_mutually_confirmed');
    }
    if (existing.employerConfirmed) {
      throw StateError('already_employer_confirmed');
    }

    if (existing.hasWorkplaceCoordinate &&
        !AttendanceGeofenceService.allowsRelaxedVerification &&
        !geofenceVerified) {
      throw StateError('geofence_failed');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      employerConfirmedAt: now,
      employerClockInLatitude: latitude,
      employerClockInLongitude: longitude,
      employerClockInVerifiedAt: geofenceVerified ? now : null,
      employerGeofenceDistanceM: geofenceDistanceMeters,
    );
    final confirmed = _applyMutualConfirmation(updated, now: now);
    await _upsert(confirmed);
    if (!existing.isMutuallyConfirmed && confirmed.isMutuallyConfirmed) {
      await _handleMutualConfirmation(confirmed);
    }
    HiringRefresh.markUpdated();
    return confirmed;
  }

  /// 구직자 출근 후 기업 무응답 자동 확인 — 비활성 (상호 출근확정 필수)
  Future<List<HiringApplication>> autoConfirmSilentEmployers({
    Duration silenceThreshold = const Duration(hours: 48),
  }) async {
    return const [];
  }

  /// 미확인 출근 예정(구직자 미체크인) 건수 — 앱 잠금 판단용
  Future<List<HiringApplication>> fetchOverdueUncheckedShifts(
    String seekerEmail,
  ) async {
    final all = await fetchForSeeker(seekerEmail);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return all.where((item) {
      if (item.status != HiringApplicationStatus.scheduled) return false;
      if (item.seekerCheckedIn) return false;
      final workDate = item.workDate;
      if (workDate == null) return false;
      final workDayStart =
          DateTime(workDate.year, workDate.month, workDate.day);
      if (workDayStart.isAfter(todayStart)) return false;
      if (workDayStart == todayStart) {
        return now.hour >= 23;
      }
      return true;
    }).toList();
  }

  HiringApplication _applyMutualConfirmation(
    HiringApplication app, {
    required DateTime now,
  }) {
    if (!app.seekerCheckedIn || !app.employerConfirmed) return app;
    if (!app.isGeofenceRequirementMet &&
        app.hasWorkplaceCoordinate &&
        !AttendanceGeofenceService.allowsRelaxedVerification) {
      return app;
    }

    final bothGeofenceVerified = !app.hasWorkplaceCoordinate ||
        AttendanceGeofenceService.allowsRelaxedVerification ||
        (app.seekerClockInVerifiedAt != null &&
            app.employerClockInVerifiedAt != null);

    if (!ProductFeatureFlags.isHiringCommissionEnabled) {
      return app.copyWith(
        status: HiringApplicationStatus.commissionPaid,
        mutuallyConfirmedAt: now,
        geofenceVerified: bothGeofenceVerified,
        commissionPaidAt: now,
        commissionAmountKrw: 0,
      );
    }

    return app.copyWith(
      status: HiringApplicationStatus.checkedIn,
      mutuallyConfirmedAt: now,
      geofenceVerified: bothGeofenceVerified,
      commissionDueAt: now.add(const Duration(minutes: 1)),
      commissionAmountKrw:
          app.commissionAmountKrw ?? CommissionCalculator.defaultKrw(),
      recruiterEmail: app.recruiterEmail ??
          AuthSession.instance.currentUser?.email,
    );
  }

  Future<HiringApplication> markCommissionPaid(String applicationId) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (!existing.isMutuallyConfirmed) {
      throw StateError('not_mutually_confirmed');
    }

    final paid = existing.copyWith(
      status: HiringApplicationStatus.commissionPaid,
      commissionPaidAt: DateTime.now(),
    );
    await _upsert(paid);
    final prompt = await CommissionChatPromptService.create();
    await prompt.dismiss(applicationId);
    HiringRefresh.markUpdated();
    return paid;
  }

  Future<void> reject(String applicationId) async {
    await _updateStatus(applicationId, HiringApplicationStatus.rejected);
  }

  Future<List<HiringApplication>> escalateOverdueCommissions() async {
    final all = await fetchAll();
    final now = DateTime.now();
    final escalated = <HiringApplication>[];

    for (final item in all) {
      if (!item.needsCommissionPayment) continue;
      final due = item.commissionDueAt;
      if (due == null || now.isBefore(due)) continue;

      final nextLevel = item.escalationLevel + 1;
      final updated = item.copyWith(escalationLevel: nextLevel);
      await _upsert(updated);
      escalated.add(updated);
    }

    if (escalated.isNotEmpty) HiringRefresh.markUpdated();
    return escalated;
  }

  Future<void> _updateStatus(
    String applicationId,
    HiringApplicationStatus status,
  ) async {
    final existing = await findById(applicationId);
    if (existing == null) return;
    await _upsert(existing.copyWith(status: status));
    HiringRefresh.markUpdated();
  }

  Future<void> _upsert(HiringApplication application) async {
    final all = await fetchAll();
    final index = all.indexWhere((item) => item.id == application.id);
    if (index >= 0) {
      all[index] = application;
    } else {
      all.insert(0, application);
    }
    await _save(all);
  }

  Future<void> _save(List<HiringApplication> items) async {
    final encoded =
        jsonEncode(items.map((item) => item.toJson()).toList());
    await _prefs.setString(_keyApplications, encoded);
  }

  static String formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    return DateFormat('MM.dd').format(time);
  }

  static String formatWorkDate(DateTime date) {
    return DateFormat('MM.dd').format(date);
  }

  static String formatWorkDateFull(DateTime date) {
    return DateFormat('yyyy.MM.dd').format(date);
  }

  static Future<void> _handleMutualConfirmation(
    HiringApplication application,
  ) async {
    await WorkAchievementService().tryAwardForApplication(application);
    await MutualAttendanceSideEffects.handle(application);
  }

  /// Dev/test — idempotent insert (skips if same id exists).
  Future<void> ensureSeedApplication(HiringApplication application) async {
    final existing = await findById(application.id);
    if (existing != null) {
      if (existing.seekerPhoneMasked.contains('****') &&
          !application.seekerPhoneMasked.contains('****')) {
        await _upsert(
          existing.copyWith(seekerPhoneMasked: application.seekerPhoneMasked),
        );
        HiringRefresh.markUpdated();
      }
      return;
    }
    await _upsert(application);
    HiringRefresh.markUpdated();
  }

  Future<void> _purgePersistedDemoApplications() async {
    final all = await fetchAll();
    final cleaned =
        all.where((item) => !item.id.startsWith('demo_')).toList();
    if (cleaned.length == all.length) return;
    await _save(cleaned);
    HiringRefresh.markUpdated();
  }
}
