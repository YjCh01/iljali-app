import 'dart:convert';

import 'package:map/features/job_seeker/domain/entities/job_bookmark.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark_folder.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/viewed_job_entry.dart';
import 'package:map/features/job_seeker/domain/utils/job_bookmark_retention_policy.dart';
import 'package:map/core/sync/member_sanction_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자 공고 보관함 — 폴더·메모·오늘 본 공고 (사용자별)
class JobBookmarkVaultRepository {
  JobBookmarkVaultRepository(this._prefs, this._userEmail);

  static const _foldersKeyPrefix = 'job_bookmark_folders_v1_';
  static const _bookmarksKeyPrefix = 'job_bookmarks_v1_';
  static const _viewedKeyPrefix = 'job_viewed_jobs_v1_';

  final SharedPreferences _prefs;
  final String _userEmail;

  String get _foldersKey => '$_foldersKeyPrefix$_userEmail';
  String get _bookmarksKey => '$_bookmarksKeyPrefix$_userEmail';
  String get _viewedKey => '$_viewedKeyPrefix$_userEmail';

  static Future<JobBookmarkVaultRepository?> create(String? userEmail) async {
    if (userEmail == null || userEmail.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return JobBookmarkVaultRepository(prefs, userEmail);
  }

  Future<List<JobBookmarkFolder>> loadFolders() async {
    final raw = _prefs.getString(_foldersKey);
    if (raw == null || raw.isEmpty) {
      final defaults = [JobBookmarkFolder.defaultFolder()];
      await _saveFolders(defaults);
      return defaults;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final folders = list
          .map(
            (e) => JobBookmarkFolder.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      if (folders.isEmpty) {
        final defaults = [JobBookmarkFolder.defaultFolder()];
        await _saveFolders(defaults);
        return defaults;
      }
      return folders;
    } catch (_) {
      final defaults = [JobBookmarkFolder.defaultFolder()];
      await _saveFolders(defaults);
      return defaults;
    }
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('폴더 이름을 입력해 주세요.');
    }
    if (folderId == JobBookmarkFolder.defaultFolderId) {
      throw ArgumentError('기본 폴더 이름은 변경할 수 없습니다.');
    }
    final folders = await loadFolders();
    if (folders.any((f) => f.id != folderId && f.name == trimmed)) {
      throw ArgumentError('같은 이름의 폴더가 있습니다.');
    }
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index == -1) {
      throw ArgumentError('폴더를 찾을 수 없습니다.');
    }
    folders[index] = folders[index].copyWith(name: trimmed);
    await _saveFolders(folders);
  }

  Future<void> deleteFolder(String folderId) async {
    if (folderId == JobBookmarkFolder.defaultFolderId) {
      throw ArgumentError('기본 폴더는 삭제할 수 없습니다.');
    }
    final folders = await loadFolders();
    if (!folders.any((f) => f.id == folderId)) {
      throw ArgumentError('폴더를 찾을 수 없습니다.');
    }
    final items = await loadBookmarks();
    final updated = items
        .map(
          (item) => item.folderId == folderId
              ? item.copyWith(folderId: JobBookmarkFolder.defaultFolderId)
              : item,
        )
        .toList();
    await _saveBookmarks(updated);
    await _saveFolders(folders.where((f) => f.id != folderId).toList());
  }

  Future<JobBookmarkFolder> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('폴더 이름을 입력해 주세요.');
    }
    final folders = await loadFolders();
    if (folders.any((f) => f.name == trimmed)) {
      throw ArgumentError('같은 이름의 폴더가 있습니다.');
    }
    final folder = JobBookmarkFolder(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await _saveFolders([...folders, folder]);
    return folder;
  }

  Future<List<JobBookmark>> loadBookmarks({String? folderId}) async {
    final items = _readBookmarksRaw();
    final purged = JobBookmarkRetentionPolicy.purgeExpired(items);
    if (purged.length != items.length) {
      await _saveBookmarks(purged);
    }
    final filtered = folderId == null
        ? purged
        : purged.where((item) => item.folderId == folderId).toList();
    filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return filtered;
  }

  Future<bool> isBookmarked(String postId) async {
    final items = await loadBookmarks();
    return items.any((item) => item.postId == postId);
  }

  Future<JobBookmark> saveBookmark(
    JobMapPin pin, {
    String? folderId,
  }) async {
    final store = await MemberSanctionStore.create();
    if (store.isVaultRestricted(_userEmail)) {
      throw StateError(
        store.vaultRestrictionMessage(_userEmail) ?? '보관함 이용이 제한됩니다.',
      );
    }
    final folders = await loadFolders();
    final targetFolderId = folderId ?? JobBookmarkFolder.defaultFolderId;
    if (!folders.any((f) => f.id == targetFolderId)) {
      throw ArgumentError('폴더를 찾을 수 없습니다.');
    }
    final items = await loadBookmarks();
    final bookmark = JobBookmark.fromPin(
      pin,
      folderId: targetFolderId,
    );
    final updated = [
      bookmark,
      ...items.where((item) => item.postId != pin.post.id),
    ];
    await _saveBookmarks(updated);
    return bookmark;
  }

  Future<void> removeBookmark(String postId) async {
    final items = await loadBookmarks();
    await _saveBookmarks(
      items.where((item) => item.postId != postId).toList(),
    );
  }

  Future<void> updateMemo(String postId, String memo) async {
    final items = await loadBookmarks();
    final index = items.indexWhere((item) => item.postId == postId);
    if (index == -1) return;
    items[index] = items[index].copyWith(memo: memo.trim());
    await _saveBookmarks(items);
  }

  Future<void> moveBookmark(String postId, String folderId) async {
    final folders = await loadFolders();
    if (!folders.any((f) => f.id == folderId)) {
      throw ArgumentError('폴더를 찾을 수 없습니다.');
    }
    final items = await loadBookmarks();
    final index = items.indexWhere((item) => item.postId == postId);
    if (index == -1) return;
    items[index] = items[index].copyWith(folderId: folderId);
    await _saveBookmarks(items);
  }

  Future<void> recordViewed(JobMapPin pin) async {
    final items = _readViewedRaw();
    final entry = ViewedJobEntry.fromPin(pin);
    final updated = [
      entry,
      ...items.where((item) => item.postId != pin.post.id),
    ];
    await _saveViewed(updated);
  }

  Future<List<ViewedJobEntry>> loadViewedToday([DateTime? now]) async {
    final anchor = now ?? DateTime.now();
    final items = _readViewedRaw()
        .where((item) => _isSameDay(item.viewedAt, anchor))
        .toList()
      ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return items;
  }

  Future<List<JobBookmark>> loadExpiringSoon([DateTime? now]) async {
    final items = await loadBookmarks();
    return JobBookmarkRetentionPolicy.itemsNeedingDeletionSuggestion(
      items,
      now,
    );
  }

  List<JobBookmark> _readBookmarksRaw() {
    final raw = _prefs.getString(_bookmarksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => JobBookmark.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<ViewedJobEntry> _readViewedRaw() {
    final raw = _prefs.getString(_viewedKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => ViewedJobEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _saveFolders(List<JobBookmarkFolder> folders) async {
    final encoded = jsonEncode(folders.map((e) => e.toJson()).toList());
    await _prefs.setString(_foldersKey, encoded);
  }

  Future<void> _saveBookmarks(List<JobBookmark> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_bookmarksKey, encoded);
  }

  Future<void> _saveViewed(List<ViewedJobEntry> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_viewedKey, encoded);
  }
}
