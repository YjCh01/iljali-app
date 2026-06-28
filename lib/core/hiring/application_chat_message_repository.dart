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
    required String companyName,
    required String postTitle,
    required String seekerName,
  }) async {
    if (EnvConfig.isComplianceApiEnabled) {
      final client = IljariApiClient();
      if (client.isEnabled) {
        try {
          final remote = await client.listChatMessages(applicationId);
          if (remote.isNotEmpty) {
            final mapped = remote.map(_fromServerRow).toList()
              ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
            await saveAll(applicationId, mapped);
            return mapped;
          }
        } on Object {
          // 서버 실패 시 로컬 폴백
        }
      }
    }

    return ensureWelcomeMessages(
      applicationId: applicationId,
      companyName: companyName,
      postTitle: postTitle,
      seekerName: seekerName,
    );
  }

  Future<void> saveAll(
    String applicationId,
    List<ApplicationChatMessage> messages,
  ) async {
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _prefs.setString(_key(applicationId), encoded);
  }

  Future<void> append(
    String applicationId,
    ApplicationChatMessage message,
  ) async {
    final current = await load(applicationId);
    await saveAll(applicationId, [...current, message]);
    await _pushToServer(applicationId, message);
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

  Future<List<ApplicationChatMessage>> ensureWelcomeMessages({
    required String applicationId,
    required String companyName,
    required String postTitle,
    required String seekerName,
  }) async {
    final existing = await load(applicationId);
    if (existing.isNotEmpty) return existing;

    final seeded = [
      ApplicationChatMessage(
        fromEmployer: true,
        text:
            '안녕하세요, $companyName 채용 담당입니다.\n「$postTitle」 지원 감사합니다.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      ApplicationChatMessage(
        fromEmployer: false,
        text: '안녕하세요, $seekerName입니다. 근무 일정 확인 부탁드립니다.',
        sentAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ];
    await saveAll(applicationId, seeded);
    for (final message in seeded) {
      await _pushToServer(applicationId, message);
    }
    return seeded;
  }

  Future<void> _pushToServer(
    String applicationId,
    ApplicationChatMessage message,
  ) async {
    if (!EnvConfig.isComplianceApiEnabled) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    try {
      await client.appendChatMessage(applicationId, {
        'sender_role': _senderRole(message),
        'sender_name': message.fromEmployer ? 'employer' : 'seeker',
        'body': message.text,
        'message_type': message.kind.name,
      });
    } on Object {
      // 로컬 메시지는 유지
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
