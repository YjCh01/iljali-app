import 'dart:convert';

import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_push_retention_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자 PUSH 받은함 — 30일 보관·보관함·삭제
class SeekerPushInboxRepository {
  SeekerPushInboxRepository(this._prefs);

  static const _storageKey = 'seeker_push_inbox_v1';

  final SharedPreferences _prefs;

  static Future<SeekerPushInboxRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerPushInboxRepository(prefs);
  }

  Future<List<SeekerPushNotification>> loadAll() async {
    final items = _readRaw();
    final purged = SeekerPushRetentionPolicy.purgeExpired(items);
    if (purged.length != items.length) {
      await _save(purged);
    }
    return purged;
  }

  Future<List<SeekerPushNotification>> loadFolder(
    SeekerPushInboxFolder folder,
  ) async {
    final all = await loadAll();
    return all.where((item) => item.folder == folder).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  Future<void> recordPush(SeekerPushNotification notification) async {
    final items = await loadAll();
    final updated = [
      notification,
      ...items.where((i) => i.id != notification.id),
    ];
    await _save(updated);
  }

  Future<void> markRead(String id) async {
    await _update(id, (item) => item.copyWith(read: true));
  }

  Future<void> moveToArchive(String id) async {
    await _update(
      id,
      (item) => item.copyWith(
        folder: SeekerPushInboxFolder.archive,
        read: true,
      ),
    );
  }

  Future<void> moveToInbox(String id) async {
    await _update(
      id,
      (item) => item.copyWith(folder: SeekerPushInboxFolder.inbox),
    );
  }

  Future<void> delete(String id) async {
    final items = await loadAll();
    await _save(items.where((item) => item.id != id).toList());
  }

  Future<void> _update(
    String id,
    SeekerPushNotification Function(SeekerPushNotification) transform,
  ) async {
    final items = await loadAll();
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    items[index] = transform(items[index]);
    await _save(items);
  }

  List<SeekerPushNotification> _readRaw() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => SeekerPushNotification.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<SeekerPushNotification> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
