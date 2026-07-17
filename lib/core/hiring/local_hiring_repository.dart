import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/attendance_geofence_service.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/sync/member_sanction_store.dart';
import 'package:map/core/hiring/commission_chat_prompt_service.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/mutual_attendance_side_effects.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/services/shuttle_route_share_on_hire_side_effects.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:map/features/corporate/domain/services/commission_payer_resolver.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/attendance/domain/entities/check_in_method.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원·예정자·출근·수수료 — 기업/구직자 공유 로컬 저장 (MVP)
class LocalHiringRepository {
  LocalHiringRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyApplications = 'hiring_applications_v1';
  static const _keyWithdrawnTombstones = 'hiring_withdrawn_tombstones_v1';

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
    final items = <HiringApplication>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        items.add(
          HiringApplication.fromJson(entry.cast<String, dynamic>()),
        );
      } on Object {
        continue;
      }
    }
    return items..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }

  Future<List<HiringApplication>> fetchForSeeker(String email) async {
    await dedupeActiveApplicationsForSeeker(email);
    final all = await fetchAll();
    return all.where((item) => item.seekerEmail == email).toList();
  }

  static String _normalizeEmail(String email) =>
      email.trim().toLowerCase();

  static int _statusRank(HiringApplicationStatus status) => switch (status) {
        HiringApplicationStatus.chatting => 5,
        HiringApplicationStatus.scheduled => 4,
        HiringApplicationStatus.checkedIn => 3,
        HiringApplicationStatus.applied => 2,
        HiringApplicationStatus.inquiry => 1,
        _ => 0,
      };

  /// 같은 공고·구직자에 활성 지원이 2건 이상이면 1건만 유지 (로컬·서버 ID 불일치 대응)
  Future<void> dedupeActiveApplicationsForSeeker(String email) async {
    final normalized = _normalizeEmail(email);
    final all = await fetchAll();
    final byPost = <String, List<HiringApplication>>{};

    for (final app in all) {
      if (_normalizeEmail(app.seekerEmail) != normalized) continue;
      if (app.status == HiringApplicationStatus.rejected ||
          app.status == HiringApplicationStatus.noShow ||
          app.status == HiringApplicationStatus.commissionPaid) {
        continue;
      }
      byPost.putIfAbsent(app.postId, () => []).add(app);
    }

    final removeIds = <String>{};
    for (final group in byPost.values) {
      if (group.length <= 1) continue;
      group.sort((a, b) {
        final byStatus = _statusRank(b.status).compareTo(_statusRank(a.status));
        if (byStatus != 0) return byStatus;
        return b.appliedAt.compareTo(a.appliedAt);
      });
      for (final dup in group.skip(1)) {
        removeIds.add(dup.id);
      }
    }

    if (removeIds.isEmpty) return;
    await _save(all.where((a) => !removeIds.contains(a.id)).toList());
    HiringRefresh.markUpdated();
  }

  /// 서버 sync — 동일 공고·구직자 로컬 건이 있으면 서버 ID로 통합
  Future<void> mergeServerApplication(HiringApplication fromServer) async {
    if (_isWithdrawnTombstone(fromServer.postId, fromServer.seekerEmail)) {
      return;
    }
    final existing = await findActiveForPost(
      postId: fromServer.postId,
      seekerEmail: fromServer.seekerEmail,
    );
    if (existing != null && existing.id != fromServer.id) {
      await _adoptServerApplicationId(
        localId: existing.id,
        serverId: fromServer.id,
      );
      await _upsert(
        existing.copyWith(
          id: fromServer.id,
          postTitle: fromServer.postTitle.isNotEmpty
              ? fromServer.postTitle
              : existing.postTitle,
          companyName: fromServer.companyName.isNotEmpty
              ? fromServer.companyName
              : existing.companyName,
          companyKey: fromServer.companyKey ?? existing.companyKey,
          workSchedule: fromServer.workSchedule.isNotEmpty
              ? fromServer.workSchedule
              : existing.workSchedule,
          status: _statusRank(fromServer.status) > _statusRank(existing.status)
              ? fromServer.status
              : existing.status,
        ),
      );
      return;
    }
    await ensureSeedApplication(fromServer);
  }

  /// 로컬 지원 ID → 서버 canonical ID (채팅 동기화 키 통일)
  Future<void> _adoptServerApplicationId({
    required String localId,
    required String serverId,
  }) async {
    if (localId.isEmpty || serverId.isEmpty || localId == serverId) return;
    final chatRepo = await ApplicationChatMessageRepository.create();
    await chatRepo.migrateApplicationId(localId, serverId);

    final all = await fetchAll();
    final idx = all.indexWhere((item) => item.id == localId);
    if (idx < 0) return;
    all.removeWhere((item) => item.id == serverId);
    all[idx] = all[idx].copyWith(id: serverId);
    await _save(all);
    HiringRefresh.markUpdated();
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
        item.postId == postId && item.status.countsAsApplied);
  }

  Future<HiringApplication?> findInquiryForPost({
    required String postId,
    required String seekerEmail,
  }) async {
    final active = await findActiveForPost(
      postId: postId,
      seekerEmail: seekerEmail,
    );
    if (active?.status == HiringApplicationStatus.inquiry) return active;
    return null;
  }

  /// 지원 전 공고 문의 — 채팅방 생성·재진입
  Future<HiringApplication> openInquiry({
    required String postId,
    required String postTitle,
    required String companyName,
    required String seekerEmail,
    required String seekerName,
    required String seekerPhoneMasked,
    String? companyKey,
    String? recruiterEmail,
    String? branchId,
    String? branchName,
    double? workplaceLatitude,
    double? workplaceLongitude,
  }) async {
    final existing = await findActiveForPost(
      postId: postId,
      seekerEmail: seekerEmail,
    );
    if (existing != null) return existing;

    final application = HiringApplication(
      id: 'inq_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      postTitle: postTitle,
      companyName: companyName,
      seekerEmail: seekerEmail,
      seekerName: seekerName,
      seekerPhoneMasked: seekerPhoneMasked,
      appliedAt: DateTime.now(),
      status: HiringApplicationStatus.inquiry,
      workSchedule: '공고 문의',
      companyKey: companyKey,
      recruiterEmail: recruiterEmail,
      branchId: branchId,
      branchName: branchName,
      workplaceLatitude: workplaceLatitude,
      workplaceLongitude: workplaceLongitude,
    );
    await _upsert(application);
    HiringRefresh.markUpdated();
    await _clearWithdrawTombstone(
      postId: application.postId,
      seekerEmail: application.seekerEmail,
    );
    await _syncApplicationToServer(application);
    return await findActiveForPost(
          postId: postId,
          seekerEmail: seekerEmail,
        ) ??
        application;
  }

  Future<HiringApplication?> findActiveForPost({
    required String postId,
    required String seekerEmail,
  }) async {
    final all = await fetchForSeeker(seekerEmail);
    for (final item in all) {
      if (item.postId != postId) continue;
      if (item.status == HiringApplicationStatus.rejected ||
          item.status == HiringApplicationStatus.noShow) {
        continue;
      }
      return item;
    }
    return null;
  }

  static bool canSeekerWithdraw(HiringApplication application) {
    if (application.seekerCheckedIn) return false;
    return switch (application.status) {
      HiringApplicationStatus.inquiry => true,
      HiringApplicationStatus.applied => true,
      HiringApplicationStatus.chatting => true,
      HiringApplicationStatus.scheduled => true,
      _ => false,
    };
  }

  static String? seekerWithdrawBlockReason(HiringApplication application) {
    if (canSeekerWithdraw(application)) return null;
    if (application.seekerCheckedIn ||
        application.status == HiringApplicationStatus.checkedIn) {
      return '출근 확인 후에는 지원을 취소할 수 없습니다.';
    }
    if (application.status == HiringApplicationStatus.commissionPaid) {
      return '정산이 완료된 근무는 취소할 수 없습니다.';
    }
    return '이 공고는 지원 취소할 수 없습니다.';
  }

  Future<bool> withdrawBySeeker({
    required String postId,
    required String seekerEmail,
  }) async {
    final application = await findActiveForPost(
      postId: postId,
      seekerEmail: seekerEmail,
    );
    if (application == null) return false;
    if (!canSeekerWithdraw(application)) {
      throw StateError(
        seekerWithdrawBlockReason(application) ?? 'not_withdrawable',
      );
    }

    final normalizedEmail = _normalizeEmail(seekerEmail);
    final all = await fetchAll();
    all.removeWhere((item) {
      if (item.postId != postId) return false;
      if (_normalizeEmail(item.seekerEmail) != normalizedEmail) return false;
      return canSeekerWithdraw(item);
    });
    await _save(all);
    await _recordWithdrawTombstone(postId: postId, seekerEmail: seekerEmail);
    await _syncWithdrawToServer(postId: postId, seekerEmail: seekerEmail);
    HiringRefresh.markUpdated();
    return true;
  }

  Future<void> _recordWithdrawTombstone({
    required String postId,
    required String seekerEmail,
  }) async {
    final email = _normalizeEmail(seekerEmail);
    final tombstones = _readWithdrawnTombstones();
    final key = '$email|$postId';
    if (tombstones.contains(key)) return;
    tombstones.add(key);
    await _prefs.setString(_keyWithdrawnTombstones, jsonEncode(tombstones.toList()));
  }

  Future<void> _clearWithdrawTombstone({
    required String postId,
    required String seekerEmail,
  }) async {
    final key = '${_normalizeEmail(seekerEmail)}|$postId';
    final tombstones = _readWithdrawnTombstones();
    if (!tombstones.remove(key)) return;
    await _prefs.setString(_keyWithdrawnTombstones, jsonEncode(tombstones.toList()));
  }

  Set<String> _readWithdrawnTombstones() {
    final raw = _prefs.getString(_keyWithdrawnTombstones);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.whereType<String>().toSet();
  }

  bool _isWithdrawnTombstone(String postId, String seekerEmail) {
    final key = '${_normalizeEmail(seekerEmail)}|$postId';
    return _readWithdrawnTombstones().contains(key);
  }

  Future<void> _syncWithdrawToServer({
    required String postId,
    required String seekerEmail,
  }) async {
    if (!EnvConfig.isComplianceApiEnabled) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    try {
      await client.withdrawApplication(
        postId: postId,
        seekerEmail: seekerEmail,
      );
    } on Object {
      // 로컬·tombstone 유지 — 다음 sync에서도 재유입 차단
    }
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
    List<ResumeItemKind> disclosedResumeItems = const [],
    List<String> requiredCredentialIds = const [],
    List<String> heldCredentialIds = const [],
  }) async {
    final existingInquiry = await findInquiryForPost(
      postId: postId,
      seekerEmail: seekerEmail,
    );
    if (existingInquiry != null) {
      final upgraded = existingInquiry.copyWith(
        status: HiringApplicationStatus.applied,
        workSchedule: workSchedule,
        seekerName: seekerName,
        seekerPhoneMasked: seekerPhoneMasked,
        employmentType: employmentType,
        workDate: suggestedWorkDate,
        companyKey: companyKey ?? existingInquiry.companyKey,
        recruiterEmail: recruiterEmail ?? existingInquiry.recruiterEmail,
        branchId: branchId ?? existingInquiry.branchId,
        branchName: branchName ?? existingInquiry.branchName,
        workplaceLatitude: workplaceLatitude ?? existingInquiry.workplaceLatitude,
        workplaceLongitude:
            workplaceLongitude ?? existingInquiry.workplaceLongitude,
        commissionAmountKrw: employmentType == JobEmploymentType.daily
            ? (hourlyWageText != null
                ? CommissionCalculator.dailyWorkerFee()
                : CommissionCalculator.defaultKrw())
            : null,
        selectedShiftDate: selectedShiftDate,
        shiftSlot: shiftSlot,
        shuttleBookingId: shuttleBookingId,
        preferredStopId: preferredStopId,
        disclosedResumeItems: disclosedResumeItems,
        requiredCredentialIds: requiredCredentialIds,
        heldCredentialIds: heldCredentialIds,
      );
      await _upsert(upgraded);
      HiringRefresh.markUpdated();
      await _clearWithdrawTombstone(
        postId: upgraded.postId,
        seekerEmail: upgraded.seekerEmail,
      );
      await _syncApplicationToServer(upgraded);
      return await findActiveForPost(
            postId: postId,
            seekerEmail: seekerEmail,
          ) ??
          upgraded;
    }

    if (await hasApplied(postId, seekerEmail)) {
      throw StateError('already_applied');
    }

    final sanctionStore = await MemberSanctionStore.create();
    if (sanctionStore.isApplyRestricted(seekerEmail)) {
      throw StateError(
        sanctionStore.applyRestrictionMessage(seekerEmail) ??
            '이용 제한으로 지원할 수 없습니다.',
      );
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
      disclosedResumeItems: disclosedResumeItems,
      requiredCredentialIds: requiredCredentialIds,
      heldCredentialIds: heldCredentialIds,
    );

    await _upsert(application);
    HiringRefresh.markUpdated();
    await _clearWithdrawTombstone(
      postId: application.postId,
      seekerEmail: application.seekerEmail,
    );
    await _syncApplicationToServer(application);
    return await findActiveForPost(
          postId: postId,
          seekerEmail: seekerEmail,
        ) ??
        application;
  }

  Future<void> _syncApplicationToServer(HiringApplication application) async {
    if (!EnvConfig.isComplianceApiEnabled) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    try {
      final booking = application.shuttleBookingId == null
          ? null
          : await (await ShuttleBookingRepository.create())
              .findById(application.shuttleBookingId!);
      final route = booking == null
          ? null
          : await (await CommuteRouteRepository.create()).findById(booking.routeId);
      final result = await client.createApplication({
        'post_id': application.postId,
        'post_title': application.postTitle,
        'company_name': application.companyName,
        'company_key': application.companyKey ?? '',
        'seeker_email': application.seekerEmail,
        'seeker_name': application.seekerName,
        'status': application.status.wireValue,
        'work_schedule': application.workSchedule,
        'required_credential_ids_json':
            jsonEncode(application.requiredCredentialIds),
        'held_credential_ids_json': jsonEncode(application.heldCredentialIds),
        if (application.workDate != null)
          'work_date': DateFormat('yyyy-MM-dd').format(application.workDate!),
        if (application.isInterviewAgreementComplete)
          'interview_at': application.interviewAt!.toIso8601String(),
        if (booking != null) ...{
          'commute_route_id': booking.routeId,
          'commute_route_name': route?.routeName ?? '',
          'shuttle_stop_id': booking.stopId,
          'shuttle_stop_label': booking.stopLabel,
          'shuttle_pickup_time': booking.pickupTime,
          'shuttle_shift_date': booking.shiftDate,
        },
      });
      final serverId = result['id'] as String?;
      if (serverId != null &&
          serverId.isNotEmpty &&
          serverId != application.id) {
        await _adoptServerApplicationId(
          localId: application.id,
          serverId: serverId,
        );
      }
    } on Object {
      // 로컬 지원은 유지 — 서버 실패는 비차단
    }
  }

  Future<HiringApplication?> findById(String id) async {
    final all = await fetchAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// 내 버스 정류장 선택 — 탑승 예약·서버 동기화
  Future<HiringApplication?> attachShuttleBooking({
    required String applicationId,
    required ShuttleBooking booking,
  }) async {
    final bookingRepo = await ShuttleBookingRepository.create();
    await bookingRepo.save(booking);
    final existing = await findById(applicationId);
    if (existing == null) return null;
    final updated = existing.copyWith(
      shuttleBookingId: booking.id,
      preferredStopId: booking.stopId,
    );
    await _upsert(updated);
    HiringRefresh.markUpdated();
    await _syncApplicationToServer(updated);
    return updated;
  }

  Future<void> startChat(String applicationId) async {
    await _updateStatus(applicationId, HiringApplicationStatus.chatting);
  }

  Future<HiringApplication> instantAccept({
    required String applicationId,
    DateTime? workDate,
  }) async {
    if (!ProductFeatureFlags.isAttendanceFlowEnabled) {
      throw StateError('attendance_flow_disabled');
    }
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
    await _handleScheduledHire(scheduled);
    return scheduled;
  }

  /// 채팅 — 근무예정 합의 (쌍방)
  Future<HiringApplication> confirmWorkScheduleAgreement({
    required String applicationId,
    required bool asEmployer,
  }) async {
    if (!ProductFeatureFlags.isAttendanceFlowEnabled) {
      throw StateError('attendance_flow_disabled');
    }
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.status == HiringApplicationStatus.rejected ||
        existing.status == HiringApplicationStatus.noShow) {
      throw StateError('not_agreeable');
    }

    final wasScheduled = existing.status == HiringApplicationStatus.scheduled;
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
    if (!wasScheduled && updated.status == HiringApplicationStatus.scheduled) {
      await _handleScheduledHire(updated);
    }
    return updated;
  }

  /// 채팅 — 면접 제안 (기업 전용). 근무예정 합의와 별개의 흐름.
  Future<HiringApplication> proposeInterview({
    required String applicationId,
    required DateTime interviewAt,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');

    final now = DateTime.now();
    final updated = existing.copyWith(
      interviewAt: interviewAt,
      employerInterviewAgreedAt: now,
      clearSeekerInterviewAgreedAt: true,
    );
    await _upsert(updated);
    HiringRefresh.markUpdated();

    final chatRepo = await ApplicationChatMessageRepository.create();
    await chatRepo.appendSystemMessage(
      applicationId: applicationId,
      text: '📅 면접 제안: ${DateFormat('M월 d일 HH:mm').format(interviewAt)}\n'
          '구직자 확인을 기다리는 중입니다.',
    );
    return updated;
  }

  /// 채팅 — 면접 일정 확인 (쌍방)
  Future<HiringApplication> confirmInterviewAgreement({
    required String applicationId,
    required bool asEmployer,
  }) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');
    if (existing.interviewAt == null) throw StateError('no_interview_proposed');

    final now = DateTime.now();
    final wasComplete = existing.isInterviewAgreementComplete;
    final updated = existing.copyWith(
      seekerInterviewAgreedAt: asEmployer
          ? existing.seekerInterviewAgreedAt
          : (existing.seekerInterviewAgreedAt ?? now),
      employerInterviewAgreedAt: asEmployer
          ? (existing.employerInterviewAgreedAt ?? now)
          : existing.employerInterviewAgreedAt,
    );
    await _upsert(updated);
    HiringRefresh.markUpdated();

    if (!wasComplete && updated.isInterviewAgreementComplete) {
      await _announceInterviewConfirmed(updated);
      await _syncApplicationToServer(updated);
    }
    return updated;
  }

  static Future<void> _announceInterviewConfirmed(
    HiringApplication application,
  ) async {
    final interviewAt = application.interviewAt;
    if (interviewAt == null) return;
    final chatRepo = await ApplicationChatMessageRepository.create();
    await chatRepo.appendSystemMessage(
      applicationId: application.id,
      text: '✅ 면접 일정이 확정되었습니다.\n'
          '· 일시: ${DateFormat('M월 d일 HH:mm').format(interviewAt)}\n\n'
          '면접 1시간 전에 알림을 보내드립니다.',
    );
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
    var updated = existing.copyWith(
      status: HiringApplicationStatus.noShow,
      noShowMarkedAt: now,
    );
    try {
      final response =
          await IljariApiClient().markApplicationNoShow(applicationId);
      final serverCount = response['seeker_no_show_count'] as num?;
      if (serverCount != null) {
        updated = updated.copyWith(seekerNoShowCount: serverCount.toInt());
      }
    } on Object {
      // 오프라인 — 로컬 상태만 반영, 서버 누적은 다음 동기화 때 재시도되지 않으므로
      // 근태 탭에서 다시 열 때 재시도할 수 있게 상태만 noShow로 남겨둔다.
    }
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
    if (!ProductFeatureFlags.isAttendanceFlowEnabled) {
      return const [];
    }
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
    await MutualAttendanceSideEffects.handle(application);
  }

  static Future<void> _handleScheduledHire(HiringApplication application) async {
    await _announceWorkScheduleConfirmed(application);
    await ShuttleRouteShareOnHireSideEffects.handle(application);
  }

  /// 근무예정 합의(양측 확인) 완료 시 — 실제 문자로 면접·근무 일정을 통보하던
  /// 관행을 대신해, 앱 채팅에 짧은 확정 안내를 자동 발송한다.
  static Future<void> _announceWorkScheduleConfirmed(
    HiringApplication application,
  ) async {
    final workDate = application.workDate;
    final dateLabel =
        workDate == null ? '' : DateFormat('M월 d일').format(workDate);
    final scheduleLabel = application.workSchedule.trim();

    final lines = StringBuffer()
      ..writeln('✅ 근무 일정이 확정되었습니다.')
      ..writeln()
      ..writeln('· 공고: ${application.postTitle}');
    if (dateLabel.isNotEmpty) lines.writeln('· 근무일: $dateLabel');
    if (scheduleLabel.isNotEmpty) lines.writeln('· 근무시간: $scheduleLabel');
    lines.writeln();
    lines.writeln('출근 시 GPS 출근 체크를 잊지 마세요.');

    final chatRepo = await ApplicationChatMessageRepository.create();
    await chatRepo.appendSystemMessage(
      applicationId: application.id,
      text: lines.toString().trim(),
    );
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
