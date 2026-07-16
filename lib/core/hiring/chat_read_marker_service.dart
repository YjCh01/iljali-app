import 'dart:convert';

import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원 건별 "마지막으로 읽은 시각" — 기기 로컬 저장, 실제 메시지 기반 안읽음 계산용.
abstract final class ChatReadMarkerService {
  static const _key = 'chat_last_read_v1';

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _storageKey(String email, String applicationId) =>
      '${_normalizeEmail(email)}::$applicationId';

  static Future<Map<String, String>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((key, value) => MapEntry(key.toString(), '$value'));
  }

  /// 채팅방 진입 시 호출 — 현재 시각을 마지막으로 읽은 시각으로 기록.
  static Future<void> markRead({
    required String applicationId,
    String? userEmail,
  }) async {
    final email = userEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();
    all[_storageKey(email, applicationId)] = DateTime.now().toIso8601String();
    await prefs.setString(_key, jsonEncode(all));
  }

  /// 상대방(fromEmployer가 asEmployer과 반대)이 보낸, 마지막으로 읽은 시각 이후 메시지 수.
  static Future<int> unreadCount({
    required String applicationId,
    required bool asEmployer,
    required List<ApplicationChatMessage> messages,
    String? userEmail,
  }) async {
    if (messages.isEmpty) return 0;
    final email = userEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return 0;
    final all = await _loadAll();
    final lastReadRaw = all[_storageKey(email, applicationId)];
    final lastRead = lastReadRaw != null ? DateTime.tryParse(lastReadRaw) : null;

    return messages.where((m) {
      if (m.fromEmployer == asEmployer) return false;
      if (lastRead == null) return true;
      return m.sentAt.isAfter(lastRead);
    }).length;
  }
}
