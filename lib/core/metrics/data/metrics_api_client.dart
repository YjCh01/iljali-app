import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/trust/company_rating.dart';

/// FastAPI metrics 라우터 클라이언트 (ROI·구직자 평가)
class MetricsApiClient {
  MetricsApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? EnvConfig.complianceApiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  Future<CompanyRatingSummary> fetchCompanyRatingSummary(
    String companyKey,
  ) async {
    final uri = Uri.parse('$_baseUrl/metrics/company/$companyKey/company-rating-summary');
    final response = await _client.get(uri);
    if (response.statusCode >= 400) {
      throw MetricsApiException('평가 요약 조회 실패 (${response.statusCode})');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return CompanyRatingSummary(
      averageStars: (map['average_stars'] as num?)?.toDouble() ?? 0,
      reviewCount: map['review_count'] as int? ?? 0,
      topTags: (map['top_tags'] as List<dynamic>?)?.map((e) => '$e').toList() ??
          const [],
    );
  }

  Future<void> submitCompanyRating(CompanyRating rating) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/metrics/company-ratings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'company_key': rating.companyKey,
        'application_id': rating.applicationId,
        'seeker_email': rating.seekerEmail,
        'stars': rating.stars,
        'branch_id': rating.branchId,
        'tags': rating.tags,
        'comment': rating.comment,
      }),
    );
    if (response.statusCode >= 400) {
      throw MetricsApiException('평가 저장 실패 (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> fetchRoiSummaryRaw({
    required String companyKey,
    required String tier,
  }) async {
    final uri = Uri.parse('$_baseUrl/metrics/company/$companyKey/roi-summary')
        .replace(queryParameters: {'tier': tier});
    final response = await _client.get(uri);
    if (response.statusCode >= 400) {
      throw MetricsApiException('ROI 요약 조회 실패 (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchBranchRoiRaw({
    required String companyKey,
    required String tier,
  }) async {
    final uri = Uri.parse('$_baseUrl/metrics/company/$companyKey/branches/roi')
        .replace(queryParameters: {'tier': tier});
    final response = await _client.get(uri);
    if (response.statusCode >= 400) {
      throw MetricsApiException('지점 ROI 조회 실패 (${response.statusCode})');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final branches = map['branches'] as List<dynamic>? ?? const [];
    return branches.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}

class MetricsApiException implements Exception {
  MetricsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
