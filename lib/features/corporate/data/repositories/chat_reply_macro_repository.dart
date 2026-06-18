import 'dart:convert';

import 'package:map/features/corporate/domain/entities/chat_reply_macro.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기업(companyKey)별 채팅 매크로 저장
class ChatReplyMacroRepository {
  ChatReplyMacroRepository(this._prefs);

  final SharedPreferences _prefs;

  static const maxMacros = 12;

  static Future<ChatReplyMacroRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ChatReplyMacroRepository(prefs);
  }

  String _key(String companyKey) => 'chat_reply_macros_$companyKey';

  Future<List<ChatReplyMacro>> load(String companyKey) async {
    final raw = _prefs.getString(_key(companyKey));
    if (raw == null || raw.isEmpty) {
      return List<ChatReplyMacro>.from(ChatReplyMacroDefaults.items);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final macros = list
          .map((e) => ChatReplyMacro.fromJson(e as Map<String, dynamic>))
          .toList();
      if (macros.isEmpty) {
        return List<ChatReplyMacro>.from(ChatReplyMacroDefaults.items);
      }
      return macros;
    } catch (_) {
      return List<ChatReplyMacro>.from(ChatReplyMacroDefaults.items);
    }
  }

  Future<void> save(String companyKey, List<ChatReplyMacro> macros) async {
    final trimmed = macros.take(maxMacros).toList();
    await _prefs.setString(
      _key(companyKey),
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> resetToDefaults(String companyKey) async {
    await save(companyKey, ChatReplyMacroDefaults.items);
  }
}
