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

    final now = DateTime.now();
    final checkedIn = existing.copyWith(
      status: HiringApplicationStatus.checkedIn,
      checkedInAt: now,
      checkInLatitude: latitude,
      checkInLongitude: longitude,
      commissionDueAt: now.add(const Duration(minutes: 1)),
      commissionAmountKrw: existing.commissionAmountKrw ??
          CommissionCalculator.defaultKrw(),
    );
    await _upsert(checkedIn);
    HiringRefresh.markUpdated();
    return checkedIn;
  }

  Future<HiringApplication> markCommissionPaid(String applicationId) async {
    final existing = await findById(applicationId);
    if (existing == null) throw StateError('not_found');

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
