import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';

/// Admin Ops API — X-Admin-Api-Key
class AdminOpsApiClient {
  AdminOpsApiClient({http.Client? client, String? baseUrl, String? apiKey})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl)
            .replaceAll(RegExp(r'/$'), ''),
        _apiKey = apiKey ?? EnvConfig.adminApiKey;

  final http.Client _client;
  final String _baseUrl;
  final String _apiKey;

  bool get isEnabled =>
      _baseUrl.isNotEmpty && _apiKey.isNotEmpty && EnvConfig.isAdminOpsConfigured;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Admin-Api-Key': _apiKey,
      };

  Future<Map<String, dynamic>> health() async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/health'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> grantWallet({
    required String companyKey,
    required int packageCredits,
    int? locationSlots,
  }) async =>
      _post('/v1/admin/ops/wallet/grant', {
        'company_key': companyKey,
        'package_credits': packageCredits,
        if (locationSlots != null) 'location_slots': locationSlots,
      });

  Future<Map<String, dynamic>> getWallet(String companyKey) async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/wallet/$companyKey'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> sanctionMember({
    required String email,
    required String action,
    String reason = '',
    int? days,
  }) async =>
      _post('/v1/admin/ops/members/sanction', {
        'email': email,
        'action': action,
        'reason': reason,
        if (days != null) 'days': days,
      });

  Future<List<Map<String, dynamic>>> searchMembers({
    String? query,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/admin/ops/members').replace(
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        'limit': '$limit',
      },
    );
    final body = _decode(await _client.get(uri, headers: _headers));
    final list = body['members'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> setJobPin({
    required String postId,
    required bool active,
    String? mapPinTier,
  }) async =>
      _post('/v1/admin/ops/entitlements/job-pin', {
        'post_id': postId,
        'recruitment_pin_active': active,
        if (mapPinTier != null) 'map_pin_tier': mapPinTier,
      });

  Future<Map<String, dynamic>> setShuttleExposure({
    required String postId,
    required bool active,
  }) async =>
      _post('/v1/admin/ops/entitlements/shuttle-exposure', {
        'post_id': postId,
        'shuttle_exposure_active': active,
      });

  Future<Map<String, dynamic>> seedSeekers({
    int count = 1000,
    int startIndex = 1,
  }) async =>
      _post('/v1/admin/ops/seed/seekers', {
        'count': count,
        'start_index': startIndex,
      });

  Future<Map<String, dynamic>> bulkImportJobs(
    List<Map<String, dynamic>> posts,
  ) async =>
      _post('/v1/admin/ops/jobs/bulk', {'posts': posts});

  Future<Map<String, dynamic>> distributeApplications({
    required String postId,
    int maxApplications = 100,
    String status = 'applied',
  }) async =>
      _post('/v1/admin/ops/scenario/applications', {
        'post_id': postId,
        'max_applications': maxApplications,
        'status': status,
      });

  Future<List<Map<String, dynamic>>> auditLogs({int limit = 50}) async {
    final uri = Uri.parse('$_baseUrl/v1/admin/ops/audit?limit=$limit');
    final body = _decode(await _client.get(uri, headers: _headers));
    final list = body['logs'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getStats() async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/stats'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw IljariApiException(
        'Admin API 오류 (${response.statusCode}): ${response.body}',
      );
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
