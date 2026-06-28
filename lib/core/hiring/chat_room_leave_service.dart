import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자별 채팅방 나가기(목록에서 숨김) — 지원·채용 상태는 유지
abstract final class ChatRoomLeaveService {
  static const _key = 'chat_left_application_ids_v1';

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<Map<String, List<String>>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, List<String>>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! List) continue;
      out[key] = value.map((e) => e.toString()).toList();
    }
    return out;
  }

  static Future<Set<String>> leftIdsForUser(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty) return {};
    final all = await _loadAll();
    return all[normalized]?.toSet() ?? {};
  }

  static Future<bool> isLeft({
    required String applicationId,
    String? userEmail,
  }) async {
    final email = userEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return false;
    final left = await leftIdsForUser(email);
    return left.contains(applicationId);
  }

  static Future<List<T>> filterVisible<T>({
    required List<T> items,
    required String Function(T item) applicationIdOf,
    String? userEmail,
  }) async {
    final email = userEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return items;
    final left = await leftIdsForUser(email);
    if (left.isEmpty) return items;
    return items
        .where((item) => !left.contains(applicationIdOf(item)))
        .toList();
  }

  static Future<bool> confirmAndLeave(
    BuildContext context, {
    required String applicationId,
    required String roomTitle,
    String? roomSubtitle,
    String? userEmail,
  }) async {
    final email = userEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 대화방을 나갈 수 있습니다.')),
        );
      }
      return false;
    }

    if (await isLeft(applicationId: applicationId, userEmail: email)) {
      return true;
    }

    final subtitleLine =
        roomSubtitle != null && roomSubtitle.isNotEmpty ? '\n$roomSubtitle' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대화방 나가기'),
        content: Text(
          '「$roomTitle」 대화방을 나갈까요?$subtitleLine\n\n'
          '나가면 채팅 목록에서 사라집니다. '
          '상대방과의 지원·채용 진행 상태는 그대로 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    await leave(applicationId: applicationId, userEmail: email);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대화방을 나갔습니다.')),
      );
    }
    return true;
  }

  static Future<void> leave({
    required String applicationId,
    String? userEmail,
  }) async {
    final email = userEmail ?? AuthSession.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;
    final normalized = _normalizeEmail(email);
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();
    final ids = all.putIfAbsent(normalized, () => <String>[]);
    if (!ids.contains(applicationId)) {
      ids.add(applicationId);
    }
    await prefs.setString(_key, jsonEncode(all));
    HiringRefresh.markUpdated();
  }
}
