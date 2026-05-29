import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
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
    String? branchId,
    String? branchName,
    double? workplaceLatitude,
    double? workplaceLongitude,
    DateTime? suggestedWorkDate,
    String? hourlyWageText,
    JobEmploymentType employmentType = JobEmploymentType.daily,
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
      branchId: branchId,
      branchName: branchName,
      workplaceLatitude: workplaceLatitude,
      workplaceLongitude: workplaceLongitude,
      commissionAmountKrw: employmentType == JobEmploymentType.daily
          ? (hourlyWageText != null
              ? CommissionCalculator.dailyWorkerFee()
              : CommissionCalculator.defaultKrw())
          : null,
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

    final scheduled = existing.copyWith(
      status: HiringApplicationStatus.scheduled,
      workDate: workDate ??
          existing.workDate ??
          DateTime.now().add(const Duration(days: 1)),
    );
    await _upsert(scheduled);
    HiringRefresh.markUpdated();
    return scheduled;
  }

  Future<HiringApplication> checkIn(
    String applicationId, {
    double? latitude,
    double? longitude,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.status != HiringApplicationStatus.scheduled) {
      throw StateError('not_scheduled');
    }
    if (existing.seekerCheckedIn) {
      throw StateError('already_checked_in');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      checkedInAt: now,
      checkInLatitude: latitude,
      checkInLongitude: longitude,
    );
    final confirmed = _applyMutualConfirmation(updated, now: now);
    await _upsert(confirmed);
    HiringRefresh.markUpdated();
    return confirmed;
  }

  /// 기업 출근 확인 — 구직자 선확인·기업 선확인 모두 지원
  Future<HiringApplication> confirmEmployerAttendance(
    String applicationId,
  ) async {
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

    final now = DateTime.now();
    final updated = existing.copyWith(employerConfirmedAt: now);
    final confirmed = _applyMutualConfirmation(updated, now: now);
    await _upsert(confirmed);
    HiringRefresh.markUpdated();
    return confirmed;
  }

  /// 구직자 출근 후 48시간 기업 무응답 시 자동 기업 확인
  Future<List<HiringApplication>> autoConfirmSilentEmployers({
    Duration silenceThreshold = const Duration(hours: 48),
  }) async {
    final all = await fetchAll();
    final now = DateTime.now();
    final autoConfirmed = <HiringApplication>[];

    for (final item in all) {
      if (item.status != HiringApplicationStatus.scheduled) continue;
      if (!item.seekerCheckedIn || item.employerConfirmed) continue;
      final checkedInAt = item.checkedInAt;
      if (checkedInAt == null) continue;
      if (now.difference(checkedInAt) < silenceThreshold) continue;

      final updated = item.copyWith(employerConfirmedAt: now);
      final confirmed = _applyMutualConfirmation(updated, now: now);
      await _upsert(confirmed);
      autoConfirmed.add(confirmed);
    }

    if (autoConfirmed.isNotEmpty) HiringRefresh.markUpdated();
    return autoConfirmed;
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

    return app.copyWith(
      status: HiringApplicationStatus.checkedIn,
      mutuallyConfirmedAt: now,
      commissionDueAt: now.add(const Duration(minutes: 1)),
      commissionAmountKrw:
          app.commissionAmountKrw ?? CommissionCalculator.defaultKrw(),
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

  Future<void> _purgePersistedDemoApplications() async {
    final all = await fetchAll();
    final cleaned =
        all.where((item) => !item.id.startsWith('demo_')).toList();
    if (cleaned.length == all.length) return;
    await _save(cleaned);
    HiringRefresh.markUpdated();
  }
}
