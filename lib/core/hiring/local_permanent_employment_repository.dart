import 'dart:convert';

import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/monthly_commission.dart';
import 'package:map/core/hiring/permanent_commission_calculator.dart';
import 'package:map/core/hiring/permanent_commission_policy.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/insurance_verification_orchestrator.dart';
import 'package:map/core/hiring/permanent_commission_sync_service.dart';
import 'package:map/core/hiring/permanent_employment_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermanentCommissionDashboardRow {
  const PermanentCommissionDashboardRow({
    required this.employment,
    required this.completedCycles,
    required this.nextBillingAt,
    required this.expectedCommissionKrw,
    required this.latestVerification,
    required this.needsInitialVerification,
    required this.needsReauthSoon,
    this.pendingCommissions = const [],
    this.recentCommissions = const [],
  });

  final PermanentEmploymentRecord employment;
  final int completedCycles;
  final DateTime nextBillingAt;
  final int expectedCommissionKrw;
  final InsuranceVerificationLog? latestVerification;
  final bool needsInitialVerification;
  final bool needsReauthSoon;
  final List<MonthlyCommission> pendingCommissions;
  final List<MonthlyCommission> recentCommissions;
}

class PermanentCommissionNotification {
  const PermanentCommissionNotification({
    required this.id,
    required this.employmentId,
    required this.seekerEmail,
    required this.companyKey,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String employmentId;
  final String seekerEmail;
  final String companyKey;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employmentId': employmentId,
        'seekerEmail': seekerEmail,
        'companyKey': companyKey,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory PermanentCommissionNotification.fromJson(Map<String, dynamic> json) {
    return PermanentCommissionNotification(
      id: json['id'] as String? ?? '',
      employmentId: json['employmentId'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      read: json['read'] as bool? ?? false,
    );
  }
}

/// 상시직 채용·인증·월 수수료 — 로컬 저장 (MVP)
class LocalPermanentEmploymentRepository {
  LocalPermanentEmploymentRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyEmployments = 'permanent_employments_v1';
  static const _keyVerifications = 'insurance_verifications_v1';
  static const _keyCommissions = 'monthly_commissions_v1';
  static const _keyNotifications = 'permanent_commission_notifications_v1';

  static Future<LocalPermanentEmploymentRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalPermanentEmploymentRepository(prefs);
  }

  Future<List<PermanentEmploymentRecord>> fetchEmployments() async {
    return _readList(_keyEmployments, PermanentEmploymentRecord.fromJson);
  }

  Future<List<InsuranceVerificationLog>> fetchVerifications() async {
    return _readList(_keyVerifications, InsuranceVerificationLog.fromJson);
  }

  Future<List<MonthlyCommission>> fetchCommissions() async {
    return _readList(_keyCommissions, MonthlyCommission.fromJson);
  }

  Future<List<PermanentCommissionNotification>> fetchNotifications({
    String? seekerEmail,
    String? companyKey,
  }) async {
    final all =
        _readListSync(_keyNotifications, PermanentCommissionNotification.fromJson);
    return all.where((item) {
      if (seekerEmail != null && item.seekerEmail != seekerEmail) return false;
      if (companyKey != null && item.companyKey != companyKey) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<PermanentEmploymentRecord> registerHire({
    required String applicationId,
    required String companyKey,
    required String companyName,
    required String seekerEmail,
    required String seekerName,
    required int monthlySalaryKrw,
    required DateTime hireDate,
  }) async {
    final employments = await fetchEmployments();
    if (employments.any((item) => item.applicationId == applicationId)) {
      throw StateError('already_registered');
    }

    final record = PermanentEmploymentRecord(
      id: 'perm_${DateTime.now().millisecondsSinceEpoch}',
      applicationId: applicationId,
      companyKey: companyKey,
      companyName: companyName,
      seekerEmail: seekerEmail,
      seekerName: seekerName,
      monthlySalaryKrw: monthlySalaryKrw,
      hireDate: hireDate,
      createdAt: DateTime.now(),
    );
    employments.insert(0, record);
    await _saveList(_keyEmployments, employments);

    await _addNotification(
      employmentId: record.id,
      seekerEmail: seekerEmail,
      companyKey: companyKey,
      title: '건강보험 인증 필요',
      body:
          '입사일 ${hireDate.toString().substring(0, 10)} 기준 7일 이내 건강보험 자격득실 간편인증을 완료해 주세요.',
    );

    await PermanentCommissionSyncService().pushEmployment(record);

    return record;
  }

  Future<InsuranceVerificationLog> saveVerification(
    InsuranceVerificationLog log,
  ) async {
    final logs = await fetchVerifications();
    logs.insert(0, log);
    await _saveList(_keyVerifications, logs);
    await PermanentCommissionSyncService().pushVerification(log);
    return log;
  }

  Future<InsuranceVerificationLog?> latestVerification(String employmentId) async {
    final logs = await fetchVerifications();
    final filtered =
        logs.where((item) => item.employmentId == employmentId).toList()
          ..sort((a, b) => b.verifiedAt.compareTo(a.verifiedAt));
    return filtered.isEmpty ? null : filtered.first;
  }

  Future<List<MonthlyCommission>> commissionsForEmployment(
    String employmentId,
  ) async {
    final all = await fetchCommissions();
    return all.where((item) => item.employmentId == employmentId).toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
  }

  Future<MonthlyCommission> saveCommission(MonthlyCommission commission) async {
    final all = await fetchCommissions();
    all.insert(0, commission);
    await _saveList(_keyCommissions, all);
    await PermanentCommissionSyncService().pushCommission(commission);
    return commission;
  }

  Future<MonthlyCommission> markCommissionCharged(
    String commissionId, {
    DateTime? chargedAt,
  }) async {
    final all = await fetchCommissions();
    final index = all.indexWhere((item) => item.id == commissionId);
    if (index < 0) throw StateError('not_found');

    final updated = MonthlyCommission(
      id: all[index].id,
      employmentId: all[index].employmentId,
      periodStart: all[index].periodStart,
      periodEnd: all[index].periodEnd,
      monthlySalaryKrw: all[index].monthlySalaryKrw,
      commissionRate: all[index].commissionRate,
      amountKrw: all[index].amountKrw,
      status: MonthlyCommissionStatus.charged,
      chargedAt: chargedAt ?? DateTime.now(),
      skipReason: all[index].skipReason,
      createdAt: all[index].createdAt,
    );
    all[index] = updated;
    await _saveList(_keyCommissions, all);
    await PermanentCommissionSyncService().pushCommission(updated);
    return updated;
  }

  Future<void> mergeRemoteEmployments({
    required String companyKey,
    required String companyName,
    required List<({
      String employmentId,
      String seekerName,
      int monthlySalaryKrw,
      DateTime hireDate,
    })> remote,
  }) async {
    if (remote.isEmpty) return;
    final employments = await fetchEmployments();
    final existingIds = employments.map((item) => item.id).toSet();

    for (final item in remote) {
      if (existingIds.contains(item.employmentId)) continue;
      employments.insert(
        0,
        PermanentEmploymentRecord(
          id: item.employmentId,
          applicationId: 'sync_${item.employmentId}',
          companyKey: companyKey,
          companyName: companyName,
          seekerEmail: 'synced@example.com',
          seekerName: item.seekerName,
          monthlySalaryKrw: item.monthlySalaryKrw,
          hireDate: item.hireDate,
          createdAt: DateTime.now(),
        ),
      );
    }

    await _saveList(_keyEmployments, employments);
  }

  Future<List<PermanentEmploymentRecord>> fetchForCompany(String companyKey) async {
    final all = await fetchEmployments();
    return all
        .where((item) => item.companyKey == companyKey && item.active)
        .toList();
  }

  Future<List<PermanentEmploymentRecord>> fetchForSeeker(String email) async {
    final all = await fetchEmployments();
    return all
        .where((item) => item.seekerEmail == email && item.active)
        .toList();
  }

  Future<List<PermanentCommissionDashboardRow>> buildDashboardRows({
    required String companyKey,
    required DateTime now,
  }) async {
    final employments = await fetchForCompany(companyKey);
    final rows = <PermanentCommissionDashboardRow>[];

    for (final employment in employments) {
      final commissions = await commissionsForEmployment(employment.id);
      final completedCycles = commissions.length;
      final nextBillingAt = employment.billingDueAt(completedCycles);
      final latest = await latestVerification(employment.id);
      final needsInitialVerification = latest == null ||
          latest.status != InsuranceVerificationStatus.verified;
      final daysToExpiry = latest == null
          ? null
          : latest.expiresAt.difference(now).inDays;
      final needsReauthSoon = daysToExpiry != null &&
          daysToExpiry >= 0 &&
          daysToExpiry <= PermanentCommissionPolicy.reauthReminderDaysBeforeExpiry;

      rows.add(
        PermanentCommissionDashboardRow(
          employment: employment,
          completedCycles: completedCycles,
          nextBillingAt: nextBillingAt,
          expectedCommissionKrw: PermanentCommissionCalculator.calculateAmount(
            employment.monthlySalaryKrw,
          ),
          latestVerification: latest,
          needsInitialVerification: needsInitialVerification,
          needsReauthSoon: needsReauthSoon,
          pendingCommissions: commissions
              .where((item) => item.status == MonthlyCommissionStatus.pending)
              .toList(),
          recentCommissions: commissions.reversed.take(3).toList(),
        ),
      );
    }

    return rows;
  }

  Future<void> processDueBillingCycles({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final employments = await fetchEmployments();

    for (final employment in employments.where((item) => item.active)) {
      final commissions = await commissionsForEmployment(employment.id);
      final cycleIndex = commissions.length;
      final dueAt = employment.billingDueAt(cycleIndex);

      if (at.isBefore(dueAt)) {
        await _maybeSendReauthReminder(employment, at);
        continue;
      }

      if (commissions.any((item) => item.periodEnd == dueAt)) continue;

      final periodStart = cycleIndex == 0
          ? employment.hireDate
          : employment.billingDueAt(cycleIndex - 1);
      final periodEnd = dueAt;
      var verification = await latestVerification(employment.id);
      var valid = verification?.isValidAt(at) ?? false;

      // API 연동 시 만료·미인증이면 서버 자동 재조회 시도
      if (!valid && EnvConfig.isComplianceApiEnabled && cycleIndex > 0) {
        final orchestrator = InsuranceVerificationOrchestrator();
        final reverify = await orchestrator.attemptAutoReverify(
          employmentId: employment.id,
          cycleNumber: cycleIndex,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        if (reverify != null) {
          final log = reverify.toLog(
            employmentId: employment.id,
            employerCompanyName: employment.companyName,
          );
          await saveVerification(log);
          verification = log;
          valid = reverify.success;
        }
      }

      if (valid) {
        final amount = PermanentCommissionCalculator.calculateAmount(
          employment.monthlySalaryKrw,
        );
        await saveCommission(
          MonthlyCommission(
            id: 'mc_${at.millisecondsSinceEpoch}_${employment.id}',
            employmentId: employment.id,
            periodStart: periodStart,
            periodEnd: periodEnd,
            monthlySalaryKrw: employment.monthlySalaryKrw,
            commissionRate: PermanentCommissionPolicy.commissionRate,
            amountKrw: amount,
            status: MonthlyCommissionStatus.pending,
            createdAt: at,
          ),
        );
        await _addNotification(
          employmentId: employment.id,
          seekerEmail: employment.seekerEmail,
          companyKey: employment.companyKey,
          title: '상시직 수수료 결제 필요',
          body:
              '${employment.companyName} · ${periodEnd.toString().substring(0, 10)} 주기 ${PermanentCommissionCalculator.formatKrw(amount)} 결제가 필요합니다.',
        );
      } else {
        await saveCommission(
          MonthlyCommission(
            id: 'mc_skip_${at.millisecondsSinceEpoch}_${employment.id}',
            employmentId: employment.id,
            periodStart: periodStart,
            periodEnd: periodEnd,
            monthlySalaryKrw: employment.monthlySalaryKrw,
            commissionRate: PermanentCommissionPolicy.commissionRate,
            amountKrw: 0,
            status: MonthlyCommissionStatus.skipped,
            skipReason: verification == null
                ? '건강보험 인증 미완료'
                : '재직 확인 실패 또는 인증 만료',
            createdAt: at,
          ),
        );
        await _addNotification(
          employmentId: employment.id,
          seekerEmail: employment.seekerEmail,
          companyKey: employment.companyKey,
          title: '상시직 수수료 미청구',
          body:
              '${employment.companyName} · ${periodEnd.toString().substring(0, 10)} 주기 재직 확인 실패로 수수료가 청구되지 않았습니다. 건강보험 인증을 다시 진행해 주세요.',
        );
      }

      await _maybeSendReauthReminder(employment, at);
    }
  }

  Future<void> _maybeSendReauthReminder(
    PermanentEmploymentRecord employment,
    DateTime now,
  ) async {
    final latest = await latestVerification(employment.id);
    if (latest == null) return;
    if (latest.status != InsuranceVerificationStatus.verified) return;

    final daysLeft = latest.expiresAt.difference(now).inDays;
    if (daysLeft < 0 ||
        daysLeft > PermanentCommissionPolicy.reauthReminderDaysBeforeExpiry) {
      return;
    }

    final notifications = await fetchNotifications(
      seekerEmail: employment.seekerEmail,
    );
    final duplicate = notifications.any(
      (item) =>
          item.employmentId == employment.id &&
          item.title == '건강보험 재인증 안내' &&
          now.difference(item.createdAt).inDays < 2,
    );
    if (duplicate) return;

    await _addNotification(
      employmentId: employment.id,
      seekerEmail: employment.seekerEmail,
      companyKey: employment.companyKey,
      title: '건강보험 재인증 안내',
      body:
          '인증 만료 ${daysLeft}일 전입니다. ${employment.companyName} 재직 확인을 위해 건강보험 간편인증을 다시 진행해 주세요.',
    );
  }

  Future<void> _addNotification({
    required String employmentId,
    required String seekerEmail,
    required String companyKey,
    required String title,
    required String body,
  }) async {
    final all =
        _readListSync(_keyNotifications, PermanentCommissionNotification.fromJson);
    all.insert(
      0,
      PermanentCommissionNotification(
        id: 'pcn_${DateTime.now().millisecondsSinceEpoch}',
        employmentId: employmentId,
        seekerEmail: seekerEmail,
        companyKey: companyKey,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
    await _saveList(_keyNotifications, all);
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    return _readListSync(key, fromJson);
  }

  List<T> _readListSync<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveList<T>(
    String key,
    List<T> items,
  ) async {
    final encoded = jsonEncode(
      items.map((item) => (item as dynamic).toJson()).toList(),
    );
    await _prefs.setString(key, encoded);
  }
}
