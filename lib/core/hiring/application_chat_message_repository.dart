import 'dart:convert';

import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/chat_message_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원 건 채팅 메시지 — 로컬 캐시 + 서버 동기화
class ApplicationChatMessageRepository {
  ApplicationChatMessageRepository(this._prefs);

  static const _keyPrefix = 'application_chat_messages_v1_';

  final SharedPreferences _prefs;

  static Future<ApplicationChatMessageRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ApplicationChatMessageRepository(prefs);
  }

  String _key(String applicationId) => '$_keyPrefix$applicationId';

  Future<List<ApplicationChatMessage>> load(String applicationId) async {
    final raw = _prefs.getString(_key(applicationId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => ApplicationChatMessage.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ApplicationChatMessage>> loadSynced({
    required String applicationId,
  }) async {
    if (EnvConfig.isComplianceApiEnabled) {
      final client = IljariApiClient();
      if (client.isEnabled) {
        try {
          final remote = await client.listChatMessages(applicationId);
          final mapped = remote.map(_fromServerRow).toList()
            ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
          await saveAll(applicationId, mapped);
          return mapped;
        } on Object {
          // 서버 실패 시 로컬 폴백
        }
        return load(applicationId);
      }
    }

    return load(applicationId);
  }

  /// 지원 ID 불일치 시 로컬·서버 채팅 키 통합
  Future<void> migrateApplicationId(String fromId, String toId) async {
    if (fromId.isEmpty || toId.isEmpty || fromId == toId) return;
    final fromMessages = await load(fromId);
    if (fromMessages.isEmpty) {
      await _prefs.remove(_key(fromId));
      return;
    }
    final toMessages = await load(toId);
    final merged = [...toMessages, ...fromMessages]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    await saveAll(toId, merged);
    await _prefs.remove(_key(fromId));
  }

  Future<void> saveAll(
    String applicationId,
    List<ApplicationChatMessage> messages,
  ) async {
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _prefs.setString(_key(applicationId), encoded);
  }

  Future<ApplicationChatMessage> append(
    String applicationId,
    ApplicationChatMessage message,
  ) async {
    final current = await load(applicationId);
    var stored = message;
    final serverRow = await _pushToServer(applicationId, message);
    if (serverRow != null) {
      stored = parseServerRow(serverRow, fallback: message);
    }
    await saveAll(applicationId, [...current, stored]);
    return stored;
  }

  /// WebSocket·REST 수신 메시지를 로컬에 병합 (중복 ID 스킵)
  Future<ApplicationChatMessage?> applyIncomingRow(
    String applicationId,
    Map<String, dynamic> row,
  ) async {
    final parsed = parseServerRow(row);
    final current = await load(applicationId);
    if (parsed.id != null && current.any((m) => m.id == parsed.id)) {
      return null;
    }
    await saveAll(applicationId, [...current, parsed]);
    return parsed;
  }

  ApplicationChatMessage parseServerRow(
    Map<String, dynamic> row, {
    ApplicationChatMessage? fallback,
  }) {
    final mapped = _fromServerRow(row);
    if (mapped.id != null || fallback == null) return mapped;
    return ApplicationChatMessage(
      id: fallback.id,
      fromEmployer: mapped.fromEmployer,
      text: mapped.text,
      sentAt: mapped.sentAt,
      isSystem: mapped.isSystem,
      kind: mapped.kind,
      attachmentPath: fallback.attachmentPath,
    );
  }

  Future<void> appendSystemMessage({
    required String applicationId,
    required String text,
  }) {
    return append(
      applicationId,
      ApplicationChatMessage(
        fromEmployer: true,
        text: text,
        sentAt: DateTime.now(),
        isSystem: true,
      ),
    );
  }

  Future<Map<String, dynamic>?> _pushToServer(
    String applicationId,
    ApplicationChatMessage message,
  ) async {
    if (!EnvConfig.isComplianceApiEnabled) return null;
    final client = IljariApiClient();
    if (!client.isEnabled) return null;
    try {
      return await client.appendChatMessage(applicationId, {
        'sender_role': _senderRole(message),
        'sender_name': message.fromEmployer ? 'employer' : 'seeker',
        'body': message.text,
        'message_type': message.kind.name,
      });
    } on Object {
      return null;
    }
  }

  String _senderRole(ApplicationChatMessage message) {
    if (message.isSystem) return 'system';
    return message.fromEmployer ? 'employer' : 'seeker';
  }

  ApplicationChatMessage _fromServerRow(Map<String, dynamic> row) {
    final role = row['sender_role'] as String? ?? 'seeker';
    final kindRaw = row['message_type'] as String? ?? 'text';
    return ApplicationChatMessage(
      id: row['id'] as String?,
      fromEmployer: role == 'employer' || role == 'system',
      text: row['body'] as String? ?? '',
      sentAt: DateTime.tryParse(row['sent_at'] as String? ?? '') ??
          DateTime.now(),
      isSystem: role == 'system',
      kind: ChatMessageKindX.parse(kindRaw),
    );
  }
}
