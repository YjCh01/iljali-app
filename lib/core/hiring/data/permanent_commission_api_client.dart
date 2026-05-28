import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/monthly_commission.dart';
import 'package:map/core/hiring/permanent_employment_record.dart';

/// FastAPI 상시직 수수료 백엔드 클라이언트
class PermanentCommissionApiClient {
  PermanentCommissionApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? EnvConfig.complianceApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<void> registerEmployment(PermanentEmploymentRecord record) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/permanent-commission/employments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employment_id': record.id,
        'application_id': record.applicationId,
        'company_key': record.companyKey,
        'company_name': record.companyName,
        'seeker_email': record.seekerEmail,
        'seeker_name': record.seekerName,
        'monthly_salary_krw': record.monthlySalaryKrw,
        'hire_date': record.hireDate.toIso8601String(),
      }),
    );
    if (response.statusCode >= 400) {
      throw PermanentCommissionApiException(
        '상시직 등록 API 오류 (${response.statusCode})',
      );
    }
  }

  Future<List<RemoteEmploymentSummary>> listEmployments(
    String companyKey,
  ) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/permanent-commission/employments/$companyKey'),
    );
    if (response.statusCode >= 400) {
      throw PermanentCommissionApiException(
        '상시직 목록 API 오류 (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => RemoteEmploymentSummary.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<void> saveInsuranceVerification(InsuranceVerificationLog log) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/permanent-commission/insurance-verifications'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'log_id': log.id,
        'employment_id': log.employmentId,
        'workplace_name': log.workplaceName,
        'employer_company_name': log.employerCompanyName,
        'company_name_matched': log.companyNameMatched,
        'employed_confirmed': log.employedConfirmed,
        'verified_at': log.verifiedAt.toIso8601String(),
        'expires_at': log.expiresAt.toIso8601String(),
        'status': log.status.name,
        'method': log.method,
        'rejection_reason': log.rejectionReason,
        'ci_hash': log.ciHash,
        'auth_provider': log.authProvider,
        'certificate_provider': log.certificateProvider,
        'cycle_number': log.cycleNumber,
        'simple_auth_session_id': log.simpleAuthSessionId,
      }),
    );
    if (response.statusCode >= 400) {
      throw PermanentCommissionApiException(
        '건강보험 인증 API 오류 (${response.statusCode})',
      );
    }
  }

  Future<void> saveMonthlyCommission(MonthlyCommission commission) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/permanent-commission/monthly-commissions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'commission_id': commission.id,
        'employment_id': commission.employmentId,
        'period_start': commission.periodStart.toIso8601String(),
        'period_end': commission.periodEnd.toIso8601String(),
        'monthly_salary_krw': commission.monthlySalaryKrw,
        'commission_rate': commission.commissionRate,
        'amount_krw': commission.amountKrw,
        'status': commission.status.name,
        'charged_at': commission.chargedAt?.toIso8601String(),
        'skip_reason': commission.skipReason,
      }),
    );
    if (response.statusCode >= 400) {
      throw PermanentCommissionApiException(
        '월 수수료 API 오류 (${response.statusCode})',
      );
    }
  }
}

class RemoteEmploymentSummary {
  const RemoteEmploymentSummary({
    required this.employmentId,
    required this.seekerName,
    required this.monthlySalaryKrw,
    required this.hireDate,
    required this.expectedCommissionKrw,
  });

  final String employmentId;
  final String seekerName;
  final int monthlySalaryKrw;
  final DateTime hireDate;
  final int expectedCommissionKrw;

  factory RemoteEmploymentSummary.fromJson(Map<String, dynamic> json) {
    return RemoteEmploymentSummary(
      employmentId: json['employment_id'] as String? ?? '',
      seekerName: json['seeker_name'] as String? ?? '',
      monthlySalaryKrw: json['monthly_salary_krw'] as int? ?? 0,
      hireDate: DateTime.tryParse(json['hire_date'] as String? ?? '') ??
          DateTime.now(),
      expectedCommissionKrw: json['expected_commission_krw'] as int? ?? 0,
    );
  }
}

class PermanentCommissionApiException implements Exception {
  PermanentCommissionApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
