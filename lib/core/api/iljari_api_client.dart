import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';

/// 일자리 백엔드 — 공고·지원·채팅·인증 API 클라이언트
class IljariApiClient {
  IljariApiClient({http.Client? client, String? baseUrl, this.accessToken})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl)
            .replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;
  String? accessToken;

  bool get isEnabled => _baseUrl.isNotEmpty;

  /// 서비스 상태 — PG·프로모션 플래그 등
  Future<Map<String, dynamic>> fetchHealth() => _get('/health');

  String get baseUrlForSocial => _baseUrl;

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = accessToken ?? AuthSession.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Auth ──

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _post('/v1/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<Map<String, dynamic>> fetchCurrentMember() async {
    return _get('/v1/auth/me');
  }

  Future<Map<String, dynamic>> sendPhoneVerificationCode(String phone) async {
    return _post('/v1/auth/phone/send', {'phone': phone});
  }

  Future<Map<String, dynamic>> verifyPhoneCode({
    required String phone,
    required String code,
    String purpose = 'signup',
  }) async {
    return _post('/v1/auth/phone/verify', {
      'phone': phone,
      'code': code,
      'purpose': purpose,
    });
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String phone,
    required String phoneVerifiedToken,
    required String displayName,
    Map<String, dynamic>? seekerProfile,
  }) async {
    return _post('/v1/auth/signup', {
      'email': email.trim().toLowerCase(),
      'password': password,
      'phone': phone,
      'phone_verified_token': phoneVerifiedToken,
      'display_name': displayName,
      if (seekerProfile != null) 'seeker_profile': seekerProfile,
    });
  }

  Future<Map<String, dynamic>> socialSignup({
    required String socialToken,
    required String phone,
    required String phoneVerifiedToken,
    String displayName = '',
    String password = '',
  }) async {
    return _post('/v1/auth/social/signup', {
      'social_token': socialToken,
      'phone': phone,
      'phone_verified_token': phoneVerifiedToken,
      if (displayName.isNotEmpty) 'display_name': displayName.trim(),
      if (password.isNotEmpty) 'password': password,
    });
  }

  Future<Map<String, dynamic>> signUpCorporate({
    required String email,
    required String password,
    required String displayName,
    required String companyName,
    required String companyKey,
    required String phone,
    required String phoneVerifiedToken,
    String department = '',
    String contactPersonName = '',
    String handlerCode = '',
    String orgRole = 'recruiter',
  }) async {
    return _post('/v1/auth/signup/corporate', {
      'email': email.trim().toLowerCase(),
      'password': password,
      'display_name': displayName,
      'phone': phone,
      'phone_verified_token': phoneVerifiedToken,
      'company_name': companyName,
      'company_key': companyKey,
      'department': department,
      'contact_person_name': contactPersonName,
      'handler_code': handlerCode,
      'org_role': orgRole,
    });
  }

  Future<Map<String, dynamic>> findEmail({
    String method = 'phone',
    String displayName = '',
    String phone = '',
    String? phoneVerifiedToken,
    String email = '',
    String? emailVerifiedToken,
  }) async {
    return _post('/v1/auth/account/find-email', {
      'method': method,
      if (displayName.isNotEmpty) 'display_name': displayName.trim(),
      if (phone.isNotEmpty) 'phone': phone,
      if (phoneVerifiedToken != null)
        'phone_verified_token': phoneVerifiedToken,
      if (email.isNotEmpty) 'email': email.trim().toLowerCase(),
      if (emailVerifiedToken != null)
        'email_verified_token': emailVerifiedToken,
    });
  }

  Future<Map<String, dynamic>> findCorporateEmail({
    String method = 'brn',
    required String contactPersonName,
    String companyKey = '',
    String email = '',
    String? emailVerifiedToken,
  }) async {
    return _post('/v1/auth/account/find-email/corporate', {
      'method': method,
      'contact_person_name': contactPersonName.trim(),
      if (companyKey.isNotEmpty) 'company_key': companyKey,
      if (email.isNotEmpty) 'email': email.trim().toLowerCase(),
      if (emailVerifiedToken != null)
        'email_verified_token': emailVerifiedToken,
    });
  }

  Future<Map<String, dynamic>> sendEmailVerificationCode(String email) async {
    return _post('/v1/auth/email/send', {'email': email.trim().toLowerCase()});
  }

  Future<Map<String, dynamic>> verifyEmailCode({
    required String email,
    required String code,
    String purpose = 'find_email',
  }) async {
    return _post('/v1/auth/email/verify', {
      'email': email.trim().toLowerCase(),
      'code': code,
      'purpose': purpose,
    });
  }

  Future<Map<String, dynamic>> resetPassword({
    String memberType = 'seeker',
    String method = 'phone',
    required String email,
    String displayName = '',
    String contactPersonName = '',
    String companyKey = '',
    String phone = '',
    String? phoneVerifiedToken,
    String? emailVerifiedToken,
    required String newPassword,
  }) async {
    return _post('/v1/auth/password/reset', {
      'member_type': memberType,
      'method': method,
      'email': email.trim().toLowerCase(),
      if (displayName.isNotEmpty) 'display_name': displayName.trim(),
      if (contactPersonName.isNotEmpty)
        'contact_person_name': contactPersonName.trim(),
      if (companyKey.isNotEmpty) 'company_key': companyKey,
      if (phone.isNotEmpty) 'phone': phone,
      if (phoneVerifiedToken != null)
        'phone_verified_token': phoneVerifiedToken,
      if (emailVerifiedToken != null)
        'email_verified_token': emailVerifiedToken,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> updateSeekerProfile(
    Map<String, dynamic> seekerProfile, {
    String? displayName,
  }) async {
    return _patch('/v1/auth/me/seeker-profile', {
      'seeker_profile': seekerProfile,
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
    });
  }

  // ── Job board ──

  Future<List<Map<String, dynamic>>> listJobPosts() async {
    final response = await _get('/v1/job-board/posts');
    final list = response['posts'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createJobPost(Map<String, dynamic> body) async {
    return _post('/v1/job-board/posts', body);
  }

  Future<Map<String, dynamic>> updateJobPost(
    String postId,
    Map<String, dynamic> body,
  ) async {
    return _put('/v1/job-board/posts/$postId', body);
  }

  Future<void> deleteJobPost(String postId) async {
    await _delete('/v1/job-board/posts/$postId');
  }

  /// 공고 본문 이미지 업로드 — 공개 URL 반환
  Future<String> uploadJobPostMedia({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/job-media/upload');
    final request = http.MultipartRequest('POST', uri);
    final token = accessToken ?? AuthSession.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureOk(response);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final url = map['url'] as String?;
    if (url == null || url.isEmpty) {
      throw IljariApiException('이미지 업로드 응답이 올바르지 않습니다.');
    }
    return url;
  }

  Future<void> recordJobPostView(String postId) async {
    if (!isEnabled) return;
    try {
      await _post('/v1/job-board/posts/$postId/view', {});
    } on Object {
      // 열람 집계 실패는 UX 차단하지 않음
    }
  }

  // ── Hiring / applications ──

  Future<List<Map<String, dynamic>>> listApplications({
    String? seekerEmail,
    String? companyKey,
  }) async {
    final query = <String, String>{};
    if (seekerEmail != null) query['seeker_email'] = seekerEmail;
    if (companyKey != null) query['company_key'] = companyKey;
    final uri = Uri.parse('$_baseUrl/v1/hiring/applications')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri);
    _ensureOk(response);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final list = map['applications'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createApplication(
    Map<String, dynamic> body,
  ) async {
    return _post('/v1/hiring/applications', body);
  }

  /// 구직자 지원 취소 — 서버 DB에서 삭제 (sync 재유입 방지)
  Future<Map<String, dynamic>> withdrawApplication({
    required String postId,
    required String seekerEmail,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/hiring/applications').replace(
      queryParameters: {
        'post_id': postId,
        'seeker_email': seekerEmail.trim().toLowerCase(),
      },
    );
    final response = await _client.delete(uri, headers: _headers);
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Chat sync ──

  Future<List<Map<String, dynamic>>> listChatMessages(
    String applicationId,
  ) async {
    final response = await _get('/v1/chat-sync/$applicationId/messages');
    final list = response['messages'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> appendChatMessage(
    String applicationId,
    Map<String, dynamic> body,
  ) async {
    return _post('/v1/chat-sync/$applicationId/messages', body);
  }

  Future<Map<String, dynamic>> registerPushDevice({
    required String fcmToken,
    bool chatEnabled = true,
    bool jobAlertsEnabled = true,
    bool applicationUpdatesEnabled = true,
    String platform = 'web',
  }) async {
    return _post('/v1/notifications/devices/register', {
      'fcm_token': fcmToken,
      'platform': platform,
      'chat_enabled': chatEnabled,
      'job_alerts_enabled': jobAlertsEnabled,
      'application_updates_enabled': applicationUpdatesEnabled,
    });
  }

  Future<Map<String, dynamic>> updatePushDevicePreferences({
    required String fcmToken,
    bool? chatEnabled,
    bool? jobAlertsEnabled,
    bool? applicationUpdatesEnabled,
  }) async {
    return _patch('/v1/notifications/devices/preferences', {
      'fcm_token': fcmToken,
      if (chatEnabled != null) 'chat_enabled': chatEnabled,
      if (jobAlertsEnabled != null) 'job_alerts_enabled': jobAlertsEnabled,
      if (applicationUpdatesEnabled != null)
        'application_updates_enabled': applicationUpdatesEnabled,
    });
  }

  Future<void> unregisterPushDevice(String fcmToken) async {
    final uri = Uri.parse('$_baseUrl/v1/notifications/devices/register')
        .replace(queryParameters: {'fcm_token': fcmToken});
    final response = await _client.delete(uri, headers: _headers);
    _ensureOk(response);
  }

  Future<Map<String, dynamic>> dispatchRecruitmentPush({
    required String postId,
    required String title,
    required String companyName,
    required String companyKey,
    required List<Map<String, dynamic>> targets,
  }) async {
    return _post('/v1/notifications/push/recruitment', {
      'post_id': postId,
      'title': title,
      'company_name': companyName,
      'company_key': companyKey,
      'targets': targets,
    });
  }

  // ── External job import ──

  Future<Map<String, dynamic>> importJobPost({
    String? url,
    String? text,
    String? platform,
  }) async {
    return _post('/v1/job-import/parse', {
      if (url != null) 'url': url,
      if (text != null) 'text': text,
      if (platform != null) 'platform': platform,
    });
  }

  Future<Map<String, dynamic>> importResume({
    String? url,
    String? text,
    String? platform,
  }) async {
    return _post('/v1/resume-import/parse', {
      if (url != null) 'url': url,
      if (text != null) 'text': text,
      if (platform != null) 'platform': platform,
    });
  }

  Future<Map<String, dynamic>> importResumeFile({
    required List<int> fileBytes,
    required String fileName,
    String platform = 'unknown',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/v1/resume-import/parse-file'),
    );
    final token = accessToken ?? AuthSession.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['platform'] = platform;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    _ensureOk(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchBusLocationTowerPilotStatus() async =>
      _get('/v1/pilot/bus-location-tower/me');

  Future<Map<String, dynamic>> updateBusLocationTowerPosition({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async =>
      _post('/v1/pilot/bus-location-tower/location', {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracy_m': accuracyMeters,
      });

  Future<Map<String, dynamic>> offerShuttleRouteShare({
    required String applicationId,
    required String companyKey,
    required String companyName,
    required int routeCount,
  }) async =>
      _post('/v1/shuttle/route-share/offer', {
        'application_id': applicationId,
        'company_key': companyKey,
        'company_name': companyName,
        'route_count': routeCount,
      });

  Future<List<Map<String, dynamic>>> fetchShuttleRouteShareConsents() async {
    final raw = await _get('/v1/shuttle/route-share/me');
    final items = raw['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> upsertShuttleRouteShareConsent({
    required String companyKey,
    required bool optedIn,
    required bool towerParticipationConsented,
    String? routeId,
    String? stopId,
    String? pickupTime,
  }) async =>
      _put('/v1/shuttle/route-share/consent', {
        'company_key': companyKey,
        'opted_in': optedIn,
        'tower_participation_consented': towerParticipationConsented,
        if (routeId != null) 'route_id': routeId,
        if (stopId != null) 'stop_id': stopId,
        if (pickupTime != null) 'pickup_time': pickupTime,
      });

  Future<List<Map<String, dynamic>>> fetchCommuteRoutes(String companyKey) async {
    final uri = Uri.parse('$_baseUrl/v1/shuttle/routes').replace(
      queryParameters: {'company_key': companyKey},
    );
    final response = await _client.get(uri, headers: _headers);
    _ensureOk(response);
    final raw = jsonDecode(response.body) as Map<String, dynamic>;
    final items = raw['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>?> fetchCommuteRouteById(String routeId) async {
    try {
      return await _get('/v1/shuttle/routes/$routeId');
    } on Object {
      return null;
    }
  }

  Future<Map<String, dynamic>> upsertCommuteRoute(
    Map<String, dynamic> route,
  ) async {
    final id = route['id'] as String? ?? '';
    return _put('/v1/shuttle/routes/$id', route);
  }

  Future<Map<String, dynamic>> refreshCommuteRouteGeometry({
    required String routeId,
    required String companyKey,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/shuttle/routes/$routeId/refresh-geometry',
    ).replace(queryParameters: {'company_key': companyKey});
    final response = await _client.post(uri, headers: _headers);
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteCommuteRoute({
    required String routeId,
    required String companyKey,
    bool hard = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/shuttle/routes/$routeId').replace(
      queryParameters: {
        'company_key': companyKey,
        'hard': hard ? 'true' : 'false',
      },
    );
    final response = await _client.delete(uri, headers: _headers);
    _ensureOk(response);
  }

  Future<List<Map<String, dynamic>>> fetchShuttlePreferences() async {
    final raw = await _get('/v1/shuttle/preferences/me');
    final items = raw['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> upsertShuttlePreference({
    required String companyKey,
    required String companyName,
    required String routeId,
    required String routeName,
    required String stopId,
    required String stopLabel,
    required String pickupTime,
  }) async =>
      _put('/v1/shuttle/preferences', {
        'company_key': companyKey,
        'company_name': companyName,
        'route_id': routeId,
        'route_name': routeName,
        'stop_id': stopId,
        'stop_label': stopLabel,
        'pickup_time': pickupTime,
      });

  Future<void> deleteShuttlePreference(String companyKey) async {
    final uri = Uri.parse('$_baseUrl/v1/shuttle/preferences').replace(
      queryParameters: {'company_key': companyKey},
    );
    final response = await _client.delete(uri, headers: _headers);
    _ensureOk(response);
  }

  // ── Push wallet ──

  Future<Map<String, dynamic>> getWallet(String companyKey) async {
    return _get('/v1/wallet/$companyKey');
  }

  Future<Map<String, dynamic>> addPackageCredits({
    required String companyKey,
    required int count,
    int? locationSlots,
  }) async {
    return _post('/v1/wallet/$companyKey/credits', {
      'count': count,
      if (locationSlots != null) 'location_slots': locationSlots,
    });
  }

  Future<Map<String, dynamic>> syncBootstrap({
    String? seekerEmail,
    String? memberEmail,
    String? companyKey,
    String? memberType,
  }) async {
    final query = <String, String>{};
    if (seekerEmail != null) query['seeker_email'] = seekerEmail;
    if (memberEmail != null) query['member_email'] = memberEmail;
    if (companyKey != null) query['company_key'] = companyKey;
    if (memberType != null) query['member_type'] = memberType;
    final uri = Uri.parse('$_baseUrl/v1/sync/bootstrap')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri);
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncMemberSanction(String email) async {
    final uri = Uri.parse('$_baseUrl/v1/sync/member/sanction').replace(
      queryParameters: {'email': email},
    );
    final response = await _client.get(uri);
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncSeekerNoShowSanction({
    required String seekerEmail,
    required int streak,
  }) async {
    if (!isEnabled) return {'applied': false};
    try {
      return await _post('/v1/hiring/seeker/no-show/sync', {
        'seeker_email': seekerEmail,
        'streak': streak,
      });
    } on Object {
      return {'applied': false};
    }
  }

  Future<Map<String, dynamic>> pushApplication(
    Map<String, dynamic> body,
  ) async {
    return createApplication(body);
  }

  Future<Map<String, dynamic>> pushJobPost(Map<String, dynamic> body) async {
    return createJobPost(body);
  }

  Future<Map<String, dynamic>> reportWorkplaceMismatch({
    required String companyKey,
    required String headOfficeAddress,
    required String workplaceAddress,
    String companyName = '',
    String postId = '',
    String postTitle = '',
    int? distanceMeters,
    String? reason,
  }) async {
    return _post('/v1/compliance/workplace-mismatch', {
      'company_key': companyKey,
      'company_name': companyName,
      'head_office_address': headOfficeAddress,
      'workplace_address': workplaceAddress,
      if (postId.isNotEmpty) 'post_id': postId,
      if (postTitle.isNotEmpty) 'post_title': postTitle,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  // ── Payments ──

  Future<Map<String, dynamic>> chargePayment(Map<String, dynamic> body) async {
    return _post('/v1/payments/charge', body);
  }

  Future<Map<String, dynamic>> confirmPayment({
    required String paymentKey,
    required String orderId,
    required int amountKrw,
  }) async {
    return _post('/v1/payments/confirm', {
      'payment_key': paymentKey,
      'order_id': orderId,
      'amount_krw': amountKrw,
    });
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
    );
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    _ensureOk(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensureOk(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _delete(String path) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 400) {
      String message = 'API 오류 (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          final detail = body['detail'];
          if (detail is String) {
            message = detail;
          } else if (detail is List && detail.isNotEmpty) {
            final first = detail.first;
            if (first is Map && first['msg'] != null) {
              message = first['msg'].toString();
            }
          }
        }
      } catch (_) {}
      if (response.statusCode == 401 &&
          (message.startsWith('API 오류') ||
              message.toLowerCase().contains('unauthorized'))) {
        message = '이메일 또는 비밀번호가 올바르지 않습니다.';
      }
      throw IljariApiException(message);
    }
  }
}

class IljariApiException implements Exception {
  IljariApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
