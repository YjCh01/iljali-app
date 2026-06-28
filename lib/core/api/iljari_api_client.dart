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

  Future<Map<String, dynamic>> signUpCorporate({
    required String email,
    required String password,
    required String displayName,
    required String companyName,
    required String companyKey,
    String phone = '',
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
      'company_name': companyName,
      'company_key': companyKey,
      'department': department,
      'contact_person_name': contactPersonName,
      'handler_code': handlerCode,
      'org_role': orgRole,
    });
  }

  Future<Map<String, dynamic>> findEmail({
    required String phone,
    required String phoneVerifiedToken,
  }) async {
    return _post('/v1/auth/account/find-email', {
      'phone': phone,
      'phone_verified_token': phoneVerifiedToken,
    });
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String phone,
    required String phoneVerifiedToken,
    required String newPassword,
  }) async {
    return _post('/v1/auth/password/reset', {
      'email': email.trim().toLowerCase(),
      'phone': phone,
      'phone_verified_token': phoneVerifiedToken,
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
  }) async {
    final query = <String, String>{};
    if (seekerEmail != null) query['seeker_email'] = seekerEmail;
    if (memberEmail != null) query['member_email'] = memberEmail;
    if (companyKey != null) query['company_key'] = companyKey;
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
          message = body['detail'].toString();
        }
      } catch (_) {}
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
