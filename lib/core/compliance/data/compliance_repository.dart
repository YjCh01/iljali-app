import 'dart:convert';

import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사업자 검증·연락 사용량·이상행위 플래그 저장 (MVP 로컬)
class ComplianceRepository {
  ComplianceRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyBusiness = 'compliance_business_records_v1';
  static const _keyContactUsage = 'compliance_contact_usage_v1';
  static const _keyAbuseFlags = 'compliance_abuse_flags_v1';
  static const _keyContactEvents = 'compliance_contact_events_v1';
  static const _keyAttendanceVerification =
      'compliance_attendance_verification_v1';

  static Future<ComplianceRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ComplianceRepository(prefs);
  }

  Future<void> saveBusinessRecord(VerifiedBusinessRecord record) async {
    final all = await fetchAllBusinessRecords();
    final brn = record.businessRegistrationNumber;
    all.removeWhere((item) => item.businessRegistrationNumber == brn);
    all.add(record);
    await _prefs.setString(
      _keyBusiness,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<VerifiedBusinessRecord>> fetchAllBusinessRecords() async {
    final raw = _prefs.getString(_keyBusiness);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => VerifiedBusinessRecord.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<VerifiedBusinessRecord?> findByBrn(String brn) async {
    final normalized = brn.replaceAll(RegExp(r'[^0-9]'), '');
    final all = await fetchAllBusinessRecords();
    for (final item in all) {
      if (item.businessRegistrationNumber == normalized) return item;
    }
    return null;
  }

  Future<int> contactAttemptsThisMonth(String companyKey) async {
    final usage = await _loadContactUsage();
    final monthKey = _monthKey(DateTime.now());
    return usage['$companyKey|$monthKey'] ?? 0;
  }

  Future<void> incrementContactAttempt(String companyKey) async {
    final usage = await _loadContactUsage();
    final monthKey = _monthKey(DateTime.now());
    final composite = '$companyKey|$monthKey';
    usage[composite] = (usage[composite] ?? 0) + 1;
    await _prefs.setString(_keyContactUsage, jsonEncode(usage));
  }

  Future<Map<String, int>> _loadContactUsage() async {
    final raw = _prefs.getString(_keyContactUsage);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry('$k', v as int? ?? 0));
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<void> addAbuseFlag(Map<String, dynamic> flag) async {
    final flags = await fetchAbuseFlags();
    flags.insert(0, {
      ...flag,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _prefs.setString(_keyAbuseFlags, jsonEncode(flags));
  }

  Future<List<Map<String, dynamic>>> fetchAbuseFlags() async {
    final raw = _prefs.getString(_keyAbuseFlags);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> logContactEvent(Map<String, dynamic> event) async {
    final events = await fetchContactEvents();
    events.insert(0, {
      ...event,
      'at': DateTime.now().toIso8601String(),
    });
    if (events.length > 200) events.removeRange(200, events.length);
    await _prefs.setString(_keyContactEvents, jsonEncode(events));
  }

  Future<List<Map<String, dynamic>>> fetchContactEvents() async {
    final raw = _prefs.getString(_keyContactEvents);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> logAttendanceVerification(Map<String, dynamic> event) async {
    final events = await fetchAttendanceVerifications();
    events.insert(0, {
      ...event,
      'at': DateTime.now().toIso8601String(),
    });
    if (events.length > 500) events.removeRange(500, events.length);
    await _prefs.setString(_keyAttendanceVerification, jsonEncode(events));
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceVerifications() async {
    final raw = _prefs.getString(_keyAttendanceVerification);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> approveAdminReview(String brn, {String? reason}) async {
    await _updateRecord(
      brn,
      (record) => record.copyWith(
        status: BusinessVerificationStatus.verified,
        requiresAdminReview: true,
        adminReviewReason: reason ?? '관리자 승인 완료',
        trustScore: 80,
      ),
    );
  }

  Future<void> rejectAdminReview(String brn, {String? reason}) async {
    await _updateRecord(
      brn,
      (record) => record.copyWith(
        status: BusinessVerificationStatus.rejected,
        adminReviewReason: reason ?? '관리자 승인 거부',
        trustScore: 0,
      ),
    );
  }

  Future<void> addEnterpriseInquiry({
    required String companyKey,
    required String companyName,
    String? contactPerson,
    String? department,
  }) async {
    await addAbuseFlag({
      'type': 'enterprise_inquiry',
      'brn': companyKey.replaceAll(RegExp(r'[^0-9]'), ''),
      'companyName': companyName,
      'contactPerson': contactPerson,
      'department': department,
      'severity': 'medium',
      'message': 'Enterprise 맞춤 견적 요청 — $companyName',
    });
  }

  Future<void> suspendCompany(String brn) async {
    await _updateRecord(
      brn,
      (record) => record.copyWith(
        status: BusinessVerificationStatus.suspended,
        adminReviewReason: '계정 정지',
        trustScore: 0,
      ),
    );
    await addAbuseFlag({
      'type': 'account_suspended',
      'brn': brn.replaceAll(RegExp(r'[^0-9]'), ''),
      'severity': 'critical',
      'message': '관리자에 의해 계정 정지',
    });
  }

  Future<void> _updateRecord(
    String brn,
    VerifiedBusinessRecord Function(VerifiedBusinessRecord record) transform,
  ) async {
    final normalized = brn.replaceAll(RegExp(r'[^0-9]'), '');
    final all = await fetchAllBusinessRecords();
    final index = all.indexWhere(
      (item) => item.businessRegistrationNumber == normalized,
    );
    if (index < 0) return;
    all[index] = transform(all[index]);
    await _prefs.setString(
      _keyBusiness,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }
}
