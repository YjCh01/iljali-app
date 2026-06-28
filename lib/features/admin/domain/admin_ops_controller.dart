import 'package:flutter/foundation.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/admin/admin_ops_api_client.dart';

/// Admin Ops UI 상태 — API 호출·토스트 메시지 공유
class AdminOpsController extends ChangeNotifier {
  AdminOpsController({AdminOpsApiClient? client})
      : _client = client ?? AdminOpsApiClient();

  final AdminOpsApiClient _client;

  AdminOpsApiClient get client => _client;
  bool get apiReady => _client.isEnabled;

  bool apiConnected = false;
  String? apiError;

  bool busy = false;
  String statusMessage = '';
  bool statusIsError = false;

  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> auditLogs = const [];
  List<Map<String, dynamic>> members = const [];

  Future<void> refreshDashboard() async {
    if (!apiReady) {
      apiConnected = false;
      apiError = 'COMPLIANCE_API_URL / ADMIN_API_KEY 미설정';
      notifyListeners();
      return;
    }
    try {
      await _client.pingPublicHealth();
      apiConnected = true;
      apiError = null;
    } on Object catch (e) {
      apiConnected = false;
      apiError = AdminApiErrors.format(e);
      _setStatus('API 연결 실패: ${AdminApiErrors.format(e)}', error: true);
      notifyListeners();
      return;
    }
    try {
      await _client.health();
      stats = await _client.getStats();
      auditLogs = await _client.auditLogs(limit: 15);
      _setStatus('');
    } on Object catch (e) {
      apiError = AdminApiErrors.format(e);
      _setStatus('운영 데이터 로드 실패: ${AdminApiErrors.format(e)}', error: true);
    }
    notifyListeners();
  }

  Future<void> refreshAudit({int limit = 100}) async {
    if (!apiReady) return;
    auditLogs = await _client.auditLogs(limit: limit);
    notifyListeners();
  }

  Future<void> searchMembers(String query) async {
    if (!apiReady) return;
    members = await _client.searchMembers(
      query: query.trim().isEmpty ? null : query.trim(),
      limit: 100,
    );
    notifyListeners();
  }

  Future<T> run<T>(
    Future<T> Function() action, {
    required String successMessage,
  }) async {
    if (busy) throw StateError('busy');
    busy = true;
    statusMessage = '처리 중…';
    statusIsError = false;
    notifyListeners();
    try {
      final result = await action();
      _setStatus(successMessage);
      await refreshDashboard();
      return result;
    } on Object catch (e) {
      _setStatus('오류: ${AdminApiErrors.format(e)}', error: true);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _setStatus(String message, {bool error = false}) {
    statusMessage = message;
    statusIsError = error;
  }
}
