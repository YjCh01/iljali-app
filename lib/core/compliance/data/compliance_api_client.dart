import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/contact_entitlement.dart';
import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';

/// FastAPI 컴플라이언스 백엔드 클라이언트
class ComplianceApiClient {
  ComplianceApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<VerifiedBusinessRecord> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
    required BusinessEntityType entityType,
    required String certificateImageRef,
    required String representativeName,
    required String openingDate,
    String? ocrBrn,
    String? ocrCompanyName,
    String? ocrRepresentativeName,
    double? ocrConfidence,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/compliance/business/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'company_name': companyName,
        'business_registration_number': businessRegistrationNumber,
        'representative_name': representativeName,
        'opening_date': openingDate,
        'entity_type': entityType.name,
        'certificate_image_ref': certificateImageRef,
        if (ocrBrn != null) 'ocr_brn': ocrBrn,
        if (ocrCompanyName != null) 'ocr_company_name': ocrCompanyName,
        if (ocrRepresentativeName != null)
          'ocr_representative_name': ocrRepresentativeName,
        if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
      }),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : null;
      throw ComplianceApiException(
        detail?.toString() ?? '사업자 검증 API 오류 (${response.statusCode})',
      );
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return VerifiedBusinessRecord(
      businessRegistrationNumber: map['company_key'] as String,
      companyName: map['company_name'] as String,
      entityType: BusinessEntityType.values.byName(map['entity_type'] as String),
      status: BusinessVerificationStatus.values.byName(map['status'] as String),
      verifiedAt: DateTime.now(),
      industryName: map['industry_name'] as String?,
      certificateImageRef: certificateImageRef,
      ntsApiMatched: map['nts_api_matched'] as bool? ?? false,
      requiresAdminReview: map['requires_admin_review'] as bool? ?? false,
      adminReviewReason: map['admin_review_reason'] as String?,
      trustScore: map['trust_score'] as int? ?? 100,
    );
  }

  /// 기업 — 사업자등록증 재검토 요청 (본인 인증 토큰 필요)
  Future<VerifiedBusinessRecord> resubmitCertificate({
    required String companyKey,
    required String certificateImageRef,
    required String accessToken,
    String note = '',
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/compliance/business/$companyKey/resubmit-certificate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'certificate_image_ref': certificateImageRef,
        'note': note,
      }),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      final detail = body is Map ? body['detail'] : null;
      throw ComplianceApiException(
        detail?.toString() ?? '재검토 요청 API 오류 (${response.statusCode})',
      );
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return VerifiedBusinessRecord(
      businessRegistrationNumber: map['company_key'] as String,
      companyName: map['company_name'] as String,
      entityType: BusinessEntityType.values.byName(map['entity_type'] as String),
      status: BusinessVerificationStatus.values.byName(map['status'] as String),
      verifiedAt: DateTime.now(),
      industryName: map['industry_name'] as String?,
      certificateImageRef: map['certificate_image_ref'] as String? ?? certificateImageRef,
      ntsApiMatched: map['nts_api_matched'] as bool? ?? false,
      requiresAdminReview: map['requires_admin_review'] as bool? ?? false,
      adminReviewReason: map['admin_review_reason'] as String?,
      trustScore: map['trust_score'] as int? ?? 100,
    );
  }

  Future<ContactAccessResult> fetchContactEntitlement(String companyKey) async {
    final uri = Uri.parse('$_baseUrl/v1/compliance/entitlements/contact')
        .replace(queryParameters: {'company_key': companyKey});
    final response = await _client.get(uri);
    if (response.statusCode >= 400) {
      throw ComplianceApiException('연락 entitlement 조회 실패');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return ContactAccessResult(
      allowed: map['allowed'] as bool? ?? false,
      blockReason: map['block_reason'] as String?,
      showPartnershipUpsell: map['show_partnership_upsell'] as bool? ?? false,
      remainingMonthlyContacts: map['remaining_monthly_contacts'] as int?,
      perContactFeeKrw: map['per_contact_fee_krw'] as int?,
    );
  }

  Future<ContactAccessResult> recordContactEvent({
    required String companyKey,
    required String applicationId,
    required String action,
    required String tier,
  }) async {
    final token = AuthSession.instance.accessToken;
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/compliance/contact-events'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'company_key': companyKey,
        'application_id': applicationId,
        'action': action,
        'tier': tier,
      }),
    );
    if (response.statusCode >= 400) {
      throw ComplianceApiException('연락 이벤트 기록 실패');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return ContactAccessResult(
      allowed: map['allowed'] as bool? ?? false,
      blockReason: map['block_reason'] as String?,
      showPartnershipUpsell: map['show_partnership_upsell'] as bool? ?? false,
      remainingMonthlyContacts: map['remaining_monthly_contacts'] as int?,
      perContactFeeKrw: map['per_contact_fee_krw'] as int?,
    );
  }

  /// 출근·근태 위치검증 이용사실을 서버 취급대장에 기록 (위치정보법).
  /// 네트워크 오류는 호출부에서 무음 처리하는 로그성 호출이므로 예외를 던지지 않는다.
  Future<void> logAttendanceVerification({
    required String applicationId,
    required String role,
    required bool allowed,
    required bool withinGeofence,
    double? distanceMeters,
    bool isMocked = false,
    String reason = '',
    double? latitude,
    double? longitude,
    String? companyKey,
  }) async {
    final token = AuthSession.instance.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      await _client.post(
        Uri.parse('$_baseUrl/v1/compliance/attendance-verification-log'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'application_id': applicationId,
          'role': role,
          'allowed': allowed,
          'within_geofence': withinGeofence,
          if (distanceMeters != null) 'distance_meters': distanceMeters,
          'is_mocked': isMocked,
          'reason': reason,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (companyKey != null) 'company_key': companyKey,
        }),
      );
    } catch (_) {
      // 로그성 호출 — 실패해도 출근 확인 흐름을 막지 않는다.
    }
  }
}

class ComplianceApiException implements Exception {
  ComplianceApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
