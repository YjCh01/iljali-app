import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/insurance_auth_provider.dart';
import 'package:map/core/hiring/insurance_verification_log.dart';

/// 건강보험 간편인증 + 자격득실 API (CODEF/Hyphen + Barocert/PortOne)
class InsuranceAuthApiClient {
  InsuranceAuthApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? EnvConfig.complianceApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<AuthSessionStart> startSession({
    required String employmentId,
    required String seekerEmail,
    required InsuranceAuthProvider provider,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/insurance-auth/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employment_id': employmentId,
        'seeker_email': seekerEmail,
        'auth_provider': provider.apiValue,
      }),
    );
    _ensureOk(response, '간편인증 세션 시작');
    return AuthSessionStart.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VerificationApiResult> completeSession({
    required String sessionId,
    String? mockCi,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/insurance-auth/sessions/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        if (mockCi != null) 'mock_ci': mockCi,
      }),
    );
    _ensureOk(response, '간편인증 완료');
    return VerificationApiResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthSessionStatus> getSession(String sessionId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/insurance-auth/sessions/$sessionId'),
    );
    _ensureOk(response, '세션 조회');
    return AuthSessionStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VerificationApiResult> reverify({
    required String employmentId,
    required int cycleNumber,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/insurance-auth/reverify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employment_id': employmentId,
        'cycle_number': cycleNumber,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
      }),
    );
    _ensureOk(response, '재직 재확인');
    return VerificationApiResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<RemoteVerificationSummary>> listVerifications(
    String employmentId,
  ) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/v1/insurance-auth/verifications/$employmentId'),
    );
    _ensureOk(response, '인증 이력 조회');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => RemoteVerificationSummary.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  void _ensureOk(http.Response response, String action) {
    if (response.statusCode >= 400) {
      throw InsuranceAuthApiException(
        '$action API 오류 (${response.statusCode})',
      );
    }
  }
}

class AuthSessionStart {
  const AuthSessionStart({
    required this.sessionId,
    required this.authProvider,
    required this.authBackend,
    required this.status,
    this.authUrl,
    this.mockCompleteAvailable = false,
    this.requiresWebview = false,
  });

  final String sessionId;
  final String authProvider;
  final String authBackend;
  final String status;
  final String? authUrl;
  final bool mockCompleteAvailable;
  final bool requiresWebview;

  factory AuthSessionStart.fromJson(Map<String, dynamic> json) {
    return AuthSessionStart(
      sessionId: json['session_id'] as String? ?? '',
      authProvider: json['auth_provider'] as String? ?? '',
      authBackend: json['auth_backend'] as String? ?? 'mock',
      status: json['status'] as String? ?? 'pending',
      authUrl: json['auth_url'] as String?,
      mockCompleteAvailable: json['mock_complete_available'] as bool? ?? false,
      requiresWebview: json['requires_webview'] as bool? ?? false,
    );
  }
}

class AuthSessionStatus {
  const AuthSessionStatus({
    required this.sessionId,
    required this.status,
    required this.authCompleted,
  });

  final String sessionId;
  final String status;
  final bool authCompleted;

  factory AuthSessionStatus.fromJson(Map<String, dynamic> json) {
    return AuthSessionStatus(
      sessionId: json['session_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      authCompleted: json['auth_completed'] as bool? ?? false,
    );
  }
}

class VerificationApiResult {
  const VerificationApiResult({
    required this.success,
    required this.logId,
    required this.workplaceName,
    required this.companyNameMatched,
    required this.employedConfirmed,
    required this.verifiedAt,
    required this.expiresAt,
    required this.status,
    this.certificateProvider,
    this.authProvider,
    this.cycleNumber = 0,
    this.rejectionReason,
    this.expectedCommissionKrw = 0,
  });

  final bool success;
  final String logId;
  final String workplaceName;
  final bool companyNameMatched;
  final bool employedConfirmed;
  final DateTime verifiedAt;
  final DateTime expiresAt;
  final String status;
  final String? certificateProvider;
  final String? authProvider;
  final int cycleNumber;
  final String? rejectionReason;
  final int expectedCommissionKrw;

  InsuranceVerificationLog toLog({
    required String employmentId,
    required String employerCompanyName,
  }) {
    return InsuranceVerificationLog(
      id: logId,
      employmentId: employmentId,
      workplaceName: workplaceName,
      employerCompanyName: employerCompanyName,
      companyNameMatched: companyNameMatched,
      employedConfirmed: employedConfirmed,
      verifiedAt: verifiedAt,
      expiresAt: expiresAt,
      status: status == 'verified'
          ? InsuranceVerificationStatus.verified
          : InsuranceVerificationStatus.rejected,
      method: authProvider != null ? '${authProvider}_simple_auth' : 'simple_auth',
      rejectionReason: rejectionReason,
      authProvider: authProvider,
      certificateProvider: certificateProvider,
      cycleNumber: cycleNumber,
    );
  }

  factory VerificationApiResult.fromJson(Map<String, dynamic> json) {
    return VerificationApiResult(
      success: json['success'] as bool? ?? false,
      logId: json['log_id'] as String? ?? '',
      workplaceName: json['workplace_name'] as String? ?? '',
      companyNameMatched: json['company_name_matched'] as bool? ?? false,
      employedConfirmed: json['employed_confirmed'] as bool? ?? false,
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'rejected',
      certificateProvider: json['certificate_provider'] as String?,
      authProvider: json['auth_provider'] as String?,
      cycleNumber: json['cycle_number'] as int? ?? 0,
      rejectionReason: json['rejection_reason'] as String?,
      expectedCommissionKrw: json['expected_commission_krw'] as int? ?? 0,
    );
  }
}

class RemoteVerificationSummary {
  const RemoteVerificationSummary({
    required this.logId,
    required this.workplaceName,
    required this.status,
    required this.verifiedAt,
    required this.expiresAt,
    this.authProvider,
    this.certificateProvider,
    this.cycleNumber = 0,
    this.rejectionReason,
  });

  final String logId;
  final String workplaceName;
  final String status;
  final DateTime verifiedAt;
  final DateTime expiresAt;
  final String? authProvider;
  final String? certificateProvider;
  final int cycleNumber;
  final String? rejectionReason;

  factory RemoteVerificationSummary.fromJson(Map<String, dynamic> json) {
    return RemoteVerificationSummary(
      logId: json['log_id'] as String? ?? '',
      workplaceName: json['workplace_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      authProvider: json['auth_provider'] as String?,
      certificateProvider: json['certificate_provider'] as String?,
      cycleNumber: json['cycle_number'] as int? ?? 0,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

class InsuranceAuthApiException implements Exception {
  InsuranceAuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
