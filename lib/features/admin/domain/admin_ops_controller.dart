import 'package:flutter/foundation.dart';
import 'package:map/core/admin/admin_ops_api_client.dart';

/// Admin Ops UI 상태 — API 호출·토스트 메시지 공유
class AdminOpsController extends ChangeNotifier {
  AdminOpsController({AdminOpsApiClient? client})
      : _client = client ?? AdminOpsApiClient();

  final AdminOpsApiClient _client;

  AdminOpsApiClient get client => _client;
  bool get apiReady => _client.isEnabled;

  bool busy = false;
  String statusMessage = '';
  bool statusIsError = false;

  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> auditLogs = const [];
  List<Map<String, dynamic>> members = const [];

  Future<void> refreshDashboard() async {
    if (!apiReady) return;
    try {
      await _client.health();
      stats = await _client.getStats();
      auditLogs = await _client.auditLogs(limit: 15);
    } on Object catch (e) {
      _setStatus('대시보드 갱신 실패: $e', error: true);
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
      _setStatus('오류: $e', error: true);
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
