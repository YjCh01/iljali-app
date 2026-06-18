import 'dart:convert';

import 'package:map/core/hiring/application_chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원 건 채팅 메시지 — SharedPreferences 영속
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
    return seeded;
  }
}
