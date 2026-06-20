import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';

/// 일자리 백엔드 — 공고·지원·채팅 동기화 API 클라이언트
class IljariApiClient {
  IljariApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl)
            .replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

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
    String? companyKey,
  }) async {
    final query = <String, String>{};
    if (seekerEmail != null) query['seeker_email'] = seekerEmail;
    if (companyKey != null) query['company_key'] = companyKey;
    final uri = Uri.parse('$_baseUrl/v1/sync/bootstrap')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri);
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    final response = await _client.get(Uri.parse('$_baseUrl$path'));
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _delete(String path) async {
    final response = await _client.delete(Uri.parse('$_baseUrl$path'));
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
