import 'dart:convert';

import 'package:map/features/chat/domain/entities/admin_announcement.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AdminAnnouncementLocalDataSource {
  Future<List<AdminAnnouncement>> fetchAll();
}

class AdminAnnouncementLocalDataSourceImpl
    implements AdminAnnouncementLocalDataSource {
  const AdminAnnouncementLocalDataSourceImpl();

  static final List<AdminAnnouncement> _items = [];

  static void replaceFromServer(List<AdminAnnouncement> items) {
    _items
      ..clear()
      ..addAll(items);
  }

  static void upsertLocal(AdminAnnouncement item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
  }

  @override
  Future<List<AdminAnnouncement>> fetchAll() async =>
      List.unmodifiable(_items);
}

/// 읽음 처리 — 공지별 ID 저장
class AdminAnnouncementReadStore {
  AdminAnnouncementReadStore(this._prefs);

  static const _key = 'admin_announcement_read_ids_v1';

  final SharedPreferences _prefs;

  static Future<AdminAnnouncementReadStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AdminAnnouncementReadStore(prefs);
  }

  Set<String> readIds() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw.toSet();
  }

  Future<void> markRead(String announcementId) async {
    final next = readIds()..add(announcementId);
    await _prefs.setStringList(_key, next.toList());
  }

  bool isRead(String announcementId) => readIds().contains(announcementId);
}
