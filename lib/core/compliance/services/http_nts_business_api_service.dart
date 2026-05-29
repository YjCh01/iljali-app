import 'dart:convert';

import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/domain/business_verification_result.dart';
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/config/env_config.dart';
import 'package:http/http.dart' as http;

/// HTTP 기반 국세청 조회 — FastAPI `/v1/compliance/business/verify` 경유 (권장)
class HttpNtsBusinessApiService implements NtsBusinessApiService {
  HttpNtsBusinessApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl)
            .replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<BusinessVerificationResult> verify(
    BusinessVerificationRequest request,
  ) async {
    final validationError = request.validate();
    if (validationError != null) {
      return BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.invalidFormat,
        failureMessage: validationError,
        apiSource: 'api_proxy',
      );
    }

    if (_baseUrl.isEmpty) {
      return const MockNtsBusinessApiService().verify(request);
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/compliance/business/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'company_name': request.companyName.trim(),
          'business_registration_number': request.normalizedBrn,
          'representative_name': request.representativeName.trim(),
          'opening_date': request.normalizedOpeningDate,
          'entity_type': 'corporation',
          'certificate_image_ref': 'nts-lookup-only',
        }),
      );

      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body);
        final detail = body is Map ? body['detail']?.toString() : null;
        return BusinessVerificationResult(
          verified: false,
          failureReason: response.statusCode == 422
              ? BusinessVerificationFailureReason.infoMismatch
              : BusinessVerificationFailureReason.apiError,
          failureMessage: detail ?? '사업자 확인 API 오류 (${response.statusCode})',
          apiSource: 'api_proxy',
        );
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final status = map['status'] as String? ?? '';
      final requiresReview = map['requires_admin_review'] as bool? ?? false;
      if (status == 'rejected' || status == 'invalid') {
        return BusinessVerificationResult(
          verified: false,
          failureReason: BusinessVerificationFailureReason.infoMismatch,
          failureMessage: map['admin_review_reason'] as String? ??
              '국세청 조회 결과 유효하지 않은 사업자입니다.',
          apiSource: map['nts_api_matched'] == true ? 'odcloud' : 'api_proxy',
        );
      }

      return BusinessVerificationResult(
        verified: true,
        companyName: map['company_name'] as String? ?? request.companyName,
        industryName: map['industry_name'] as String? ?? '',
        businessStatus: status,
        entityTypeLabel: map['entity_type'] as String? ?? '',
        apiSource: map['nts_api_matched'] == true ? 'odcloud' : 'api_proxy',
        ntsMatched: map['nts_api_matched'] as bool? ?? false,
        failureMessage: requiresReview ? map['admin_review_reason'] as String? : null,
      );
    } on Object {
      return const BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.apiError,
        failureMessage: '사업자 확인 서버에 연결할 수 없습니다.',
        apiSource: 'api_proxy',
      );
    }
  }

  @override
  Future<NtsBusinessLookupResult> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
  }) {
    return verify(
      BusinessVerificationRequest(
        businessRegistrationNumber: businessRegistrationNumber,
        representativeName: MockNtsBusinessApiService.devRepresentativeName,
        openingDate: MockNtsBusinessApiService.devOpeningDate,
        companyName: companyName,
      ),
    ).then(NtsBusinessLookupResult.fromVerificationResult);
  }
}
