import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/config/env_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// HTTP 기반 국세청 조회 — 서버 /health·verify 경유 또는 직접 odcloud (키 설정 시)
class HttpNtsBusinessApiService implements NtsBusinessApiService {
  HttpNtsBusinessApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;
  final MockNtsBusinessApiService _fallback = const MockNtsBusinessApiService();

  @override
  Future<NtsBusinessLookupResult> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
  }) async {
    if (_baseUrl.isEmpty) {
      return _fallback.verifyBusiness(
        businessRegistrationNumber: businessRegistrationNumber,
        companyName: companyName,
      );
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/compliance/business/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'company_name': companyName,
          'business_registration_number': businessRegistrationNumber,
          'entity_type': 'corporation',
          'certificate_image_ref': 'nts-lookup-only',
        }),
      );
      if (response.statusCode >= 400) {
        return _fallback.verifyBusiness(
          businessRegistrationNumber: businessRegistrationNumber,
          companyName: companyName,
        );
      }
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return NtsBusinessLookupResult(
        valid: true,
        companyName: map['company_name'] as String? ?? companyName,
        industryName: map['industry_name'] as String? ?? '',
        businessStatus: map['status'] as String? ?? 'verified',
        entityTypeLabel: '법인',
        apiSource: map['nts_api_matched'] == true ? 'odcloud' : 'api_proxy',
      );
    } on Object {
      return _fallback.verifyBusiness(
        businessRegistrationNumber: businessRegistrationNumber,
        companyName: companyName,
      );
    }
  }
}
