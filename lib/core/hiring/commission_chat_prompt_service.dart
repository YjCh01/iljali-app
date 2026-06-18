import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 상호 출근 확인 직후 채팅·결제 관리 탭에서 수수료 결제를 띄울 건 ID
class CommissionChatPromptService {
  CommissionChatPromptService(this._prefs);

  static const _keyIds = 'commission_chat_prompt_ids_v1';
  static const _keyPayers = 'commission_chat_prompt_payers_v1';

  final SharedPreferences _prefs;

  static Future<CommissionChatPromptService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CommissionChatPromptService(prefs);
  }

  Set<String> _readIds() {
    final raw = _prefs.getStringList(_keyIds);
    if (raw == null) return {};
    return raw.toSet();
  }

  Map<String, String> _readPayerMap() {
    final raw = _prefs.getString(_keyPayers);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry('$k', '$v'));
  }

  Future<void> _savePayerMap(Map<String, String> map) async {
    await _prefs.setString(_keyPayers, jsonEncode(map));
  }

  Future<void> markPending(String applicationId, {String? payerEmail}) async {
    final ids = _readIds()..add(applicationId);
    await _prefs.setStringList(_keyIds, ids.toList());
    if (payerEmail != null && payerEmail.trim().isNotEmpty) {
      final map = _readPayerMap()..[applicationId] = payerEmail.trim();
      await _savePayerMap(map);
    }
  }

  Future<String?> payerEmailFor(String applicationId) async {
    return _readPayerMap()[applicationId];
  }

  Future<List<String>> consumePending() async {
    final ids = _readIds().toList();
    if (ids.isEmpty) return const [];
    await _prefs.remove(_keyIds);
    await _prefs.remove(_keyPayers);
    return ids;
  }

  /// 현재 로그인 사용자(결제 권한자)에게 해당하는 프롬프트만 반환·소비
  Future<List<String>> consumePendingForEmail(String email) async {
    final ids = _readIds().toList();
    if (ids.isEmpty) return const [];
    final payerMap = _readPayerMap();
    final normalized = email.trim().toLowerCase();
    final mine = ids.where((id) {
      final payer = payerMap[id];
      if (payer == null || payer.isEmpty) return true;
      return payer.trim().toLowerCase() == normalized;
    }).toList();

    final remainingIds = ids.where((id) => !mine.contains(id)).toList();
    await _prefs.setStringList(_keyIds, remainingIds);
    final remainingMap = Map<String, String>.from(payerMap)
      ..removeWhere((id, _) => mine.contains(id));
    await _savePayerMap(remainingMap);
    return mine;
  }

  Future<void> dismiss(String applicationId) async {
    final ids = _readIds()..remove(applicationId);
    await _prefs.setStringList(_keyIds, ids.toList());
    final map = _readPayerMap()..remove(applicationId);
    await _savePayerMap(map);
  }
}
