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

  /// 인증 없이 API 생존 확인 (CORS·네트워크)
  Future<Map<String, dynamic>> pingPublicHealth() async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/health'),
      ));

  Future<Map<String, dynamic>> grantWallet({
    required String companyKey,
    int packageCredits = 0,
    int shuttleStopCredits = 0,
    int pushTicketCredits = 0,
    int? locationSlots,
  }) async =>
      _post('/v1/admin/ops/wallet/grant', {
        'company_key': companyKey,
        'package_credits': packageCredits,
        'shuttle_stop_credits': shuttleStopCredits,
        'push_ticket_credits': pushTicketCredits,
        if (locationSlots != null) 'location_slots': locationSlots,
      });

  Future<Map<String, dynamic>> getWallet(String companyKey) async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/wallet/$companyKey'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> getCompanyVerification(String companyKey) async =>
      _decode(await _client.get(
        Uri.parse(
          '$_baseUrl/v1/admin/ops/companies/${Uri.encodeComponent(companyKey)}/verification',
        ),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> approveCompanyVerification(
    String companyKey, {
    String? reason,
  }) async =>
      _post(
        '/v1/admin/ops/companies/${Uri.encodeComponent(companyKey)}/approve-verification',
        {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );

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

  /// 알바몬 등 URL 목록 → 스크래핑 후 공고 일괄 등록
  Future<Map<String, dynamic>> bulkImportJobUrls({
    String? urlText,
    List<String>? urls,
    String companyKey = '5403100894',
    String companyName = '아라컴퍼니',
    String postedByEmail = '',
    String postedByName = '',
    bool activateJobPin = true,
  }) async =>
      _post('/v1/admin/ops/jobs/bulk-import-urls', {
        if (urlText != null && urlText.trim().isNotEmpty) 'url_text': urlText,
        if (urls != null && urls.isNotEmpty) 'urls': urls,
        'company_key': companyKey,
        'company_name': companyName,
        'posted_by_email': postedByEmail,
        'posted_by_name': postedByName,
        'activate_job_pin': activateJobPin,
      });

  Future<Map<String, dynamic>> getBusLocationTowerPilot() async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/pilot/bus-location-tower'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> searchBusLocationTowerCandidates({
    required String phone,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/admin/ops/pilot/bus-location-tower/candidates',
    ).replace(queryParameters: {'phone': phone.trim()});
    return _decode(await _client.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> setBusLocationTowerPilot({
    required String seekerEmail,
    required bool enabled,
    String companyKey = '',
    String companyName = '',
    String routeId = '',
    String routeName = '',
    String note = '',
    String workStartTime = '',
  }) async =>
      _post('/v1/admin/ops/pilot/bus-location-tower', {
        'seeker_email': seekerEmail.trim().toLowerCase(),
        'enabled': enabled,
        'company_key': companyKey.trim(),
        'company_name': companyName.trim(),
        'route_id': routeId.trim(),
        'route_name': routeName.trim(),
        'note': note,
        'work_start_time': workStartTime.trim(),
      });

  Future<Map<String, dynamic>> stopBusLocationTowerToday() async =>
      _post('/v1/admin/ops/pilot/bus-location-tower/stop-today', {});

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

  Future<List<Map<String, dynamic>>> listMapJobs() async {
    final body = _decode(await _client.get(
      Uri.parse('$_baseUrl/v1/admin/ops/jobs/map'),
      headers: _headers,
    ));
    final list = body['jobs'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getJobMapDetail(String postId) async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/jobs/map/$postId'),
        headers: _headers,
      ));

  Future<List<Map<String, dynamic>>> listGhostPins() async {
    final body = _decode(await _client.get(
      Uri.parse('$_baseUrl/v1/admin/ops/ghost-pins'),
      headers: _headers,
    ));
    final list = body['ghost_pins'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createGhostPin({
    required double latitude,
    required double longitude,
    String label = '',
    String sourcePostId = '',
  }) async =>
      _post('/v1/admin/ops/ghost-pins', {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'source_post_id': sourcePostId,
      });

  Future<void> deleteGhostPin(String pinId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/admin/ops/ghost-pins/$pinId'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<List<Map<String, dynamic>>> listGhostRoutes() async {
    final body = _decode(await _client.get(
      Uri.parse('$_baseUrl/v1/admin/ops/ghost-routes'),
      headers: _headers,
    ));
    final list = body['ghost_routes'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createGhostRoute({
    required double workplaceLatitude,
    required double workplaceLongitude,
    required List<Map<String, double>> stops,
    String label = '',
  }) async =>
      _post('/v1/admin/ops/ghost-routes', {
        'workplace_latitude': workplaceLatitude,
        'workplace_longitude': workplaceLongitude,
        'stops': stops,
        'label': label,
      });

  Future<void> deleteGhostRoute(String routeId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/v1/admin/ops/ghost-routes/$routeId'),
      headers: _headers,
    );
    _decode(response);
  }

  Future<List<Map<String, dynamic>>> listAnnouncements() async {
    final body = _decode(await _client.get(
      Uri.parse('$_baseUrl/v1/admin/ops/announcements'),
      headers: _headers,
    ));
    final list = body['announcements'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    String audience = 'all',
    bool pushRequested = true,
  }) async =>
      _post('/v1/admin/ops/announcements', {
        'title': title,
        'body': body,
        'audience': audience,
        'push_requested': pushRequested,
      });

  Future<List<Map<String, dynamic>>> listApplications({
    String? seekerEmail,
    String? companyKey,
    String? query,
    int limit = 100,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/admin/ops/applications').replace(
      queryParameters: {
        if (seekerEmail != null && seekerEmail.isNotEmpty)
          'seeker_email': seekerEmail,
        if (companyKey != null && companyKey.isNotEmpty) 'company_key': companyKey,
        if (query != null && query.isNotEmpty) 'q': query,
        'limit': '$limit',
      },
    );
    final body = _decode(await _client.get(uri, headers: _headers));
    final list = body['applications'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getApplicationChat(String applicationId) async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/applications/$applicationId/chat'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> getCorporateDirectory({
    String? query,
    String sort = 'brn',
  }) async {
    final uri =
        Uri.parse('$_baseUrl/v1/admin/ops/members/directory/corporate').replace(
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        'sort': sort,
      },
    );
    return _decode(await _client.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> getEmployerDirectory({
    String? query,
    String sort = 'joined',
    int limit = 500,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/v1/admin/ops/members/directory/employers').replace(
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        'sort': sort,
        'limit': '$limit',
      },
    );
    return _decode(await _client.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> seedEmployers() async =>
      _post('/v1/admin/ops/seed/employers', {});

  Future<Map<String, dynamic>> getSanctionPolicy() async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/sanction/policy'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> getMemberSanctionStatus(String email) async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/members/${Uri.encodeComponent(email)}/sanction'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> applyPolicySanction({
    required String email,
    required String memberKind,
    required String violationCode,
    String reason = '',
    int? days,
    bool permanent = false,
    String? companyKey,
  }) async =>
      _post('/v1/admin/ops/sanction/apply', {
        'email': email,
        'member_kind': memberKind,
        'violation_code': violationCode,
        'reason': reason,
        if (days != null) 'days': days,
        'permanent': permanent,
        if (companyKey != null && companyKey.isNotEmpty) 'company_key': companyKey,
      });

  Future<Map<String, dynamic>> liftSanction({
    required String email,
    String reason = '',
  }) async =>
      _post('/v1/admin/ops/sanction/lift', {
        'email': email,
        'reason': reason,
        'action': 'lift',
      });

  Future<List<Map<String, dynamic>>> listWorkplaceMismatchPending() async {
    final body = _decode(await _client.get(
      Uri.parse('$_baseUrl/v1/admin/ops/compliance/workplace-mismatch/pending'),
      headers: _headers,
    ));
    final list = body['flags'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> approveStatedWorkplacePost(int flagId) async =>
      _post(
        '/v1/admin/ops/compliance/workplace-mismatch/$flagId/approve-stated-workplace',
        {},
      );

  Future<Map<String, dynamic>> getShuttleParticipants() async =>
      _decode(await _client.get(
        Uri.parse('$_baseUrl/v1/admin/ops/shuttle/participants'),
        headers: _headers,
      ));

  Future<Map<String, dynamic>> bulkImportShuttleRoutes({
    required String companyKey,
    required List<int> fileBytes,
    required String fileName,
    bool replaceExisting = true,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/v1/admin/ops/shuttle/routes/bulk-import'),
    );
    request.headers['X-Admin-Api-Key'] = _apiKey;
    request.fields['company_key'] = companyKey;
    request.fields['replace_existing'] = replaceExisting.toString();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

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
