import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/domain/business_verification_result.dart';

/// 공공데이터포털 — 국세청 사업자등록정보 진위확인·상태조회 (odcloud REST)
///
/// 홈택스 스크래핑이 아닌 공식 OpenAPI:
/// - POST /nts-businessman/v1/validate
/// - POST /nts-businessman/v1/status
class OdcloudNtsBusinessApiService implements NtsBusinessApiService {
  OdcloudNtsBusinessApiService({
    required this.serviceKey,
    http.Client? client,
    this.validateUrl =
        'https://api.odcloud.kr/api/nts-businessman/v1/validate',
    this.statusUrl = 'https://api.odcloud.kr/api/nts-businessman/v1/status',
  }) : _client = client ?? http.Client();

  final String serviceKey;
  final String validateUrl;
  final String statusUrl;
  final http.Client _client;

  @override
  Future<BusinessVerificationResult> verify(BusinessVerificationRequest request) async {
    final validationError = request.validate();
    if (validationError != null) {
      return BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.invalidFormat,
        failureMessage: validationError,
        apiSource: 'odcloud',
      );
    }

    if (serviceKey.isEmpty) {
      return const BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.apiUnavailable,
        failureMessage:
            '사업자 확인 API 키가 설정되지 않았습니다. 관리자에게 문의해 주세요.',
        apiSource: 'odcloud',
      );
    }

    try {
      final validateUri = Uri.parse(validateUrl).replace(
        queryParameters: {
          'serviceKey': serviceKey,
          'returnType': 'JSON',
        },
      );
      final validateResponse = await _client.post(
        validateUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'businesses': [request.toNtsValidatePayload()],
        }),
      );

      if (validateResponse.statusCode >= 400) {
        return BusinessVerificationResult(
          verified: false,
          failureReason: BusinessVerificationFailureReason.apiError,
          failureMessage:
              '국세청 사업자 확인 서비스 오류 (${validateResponse.statusCode})',
          apiSource: 'odcloud',
        );
      }

      final validateBody =
          jsonDecode(validateResponse.body) as Map<String, dynamic>;
      final data = validateBody['data'];
      if (data is! List || data.isEmpty) {
        return BusinessVerificationResult(
          verified: false,
          failureReason: BusinessVerificationFailureReason.apiError,
          failureMessage: '국세청 응답을 해석할 수 없습니다.',
          apiSource: 'odcloud',
        );
      }

      final item = data.first as Map<String, dynamic>;
      final result = BusinessVerificationResult.fromOdcloudValidateItem(
        item,
        fallbackCompanyName: request.companyName.trim(),
        apiSource: 'odcloud',
      );
      if (result.verified || result.ntsMatched) {
        return result;
      }

      // validate 실패 시 status로 미등록 여부 보강
      return _statusFallback(request, result);
    } on Object {
      return const BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.apiError,
        failureMessage: '사업자 확인 중 네트워크 오류가 발생했습니다.',
        apiSource: 'odcloud',
      );
    }
  }

  Future<BusinessVerificationResult> _statusFallback(
    BusinessVerificationRequest request,
    BusinessVerificationResult prior,
  ) async {
    try {
      final statusUri = Uri.parse(statusUrl).replace(
        queryParameters: {
          'serviceKey': serviceKey,
          'returnType': 'JSON',
        },
      );
      final statusResponse = await _client.post(
        statusUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'b_no': [request.normalizedBrn],
        }),
      );
      if (statusResponse.statusCode >= 400) return prior;

      final statusBody =
          jsonDecode(statusResponse.body) as Map<String, dynamic>;
      final data = statusBody['data'];
      if (data is! List || data.isEmpty) return prior;

      final statusResult = BusinessVerificationResult.fromOdcloudStatusItem(
        data.first as Map<String, dynamic>,
        fallbackCompanyName: request.companyName.trim(),
        apiSource: 'odcloud',
      );
      if (!statusResult.verified) return statusResult;
      return prior;
    } on Object {
      return prior;
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
