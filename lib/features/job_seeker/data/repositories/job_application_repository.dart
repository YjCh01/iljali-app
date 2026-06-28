import 'dart:convert';

import 'package:map/features/job_seeker/domain/entities/job_application.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자 지원 내역 로컬 저장 (사용자 이메일별)
class JobApplicationRepository {
  JobApplicationRepository(this._prefs, this._userEmail);

  final SharedPreferences _prefs;
  final String _userEmail;

  static const _keyPrefix = 'job_applications_';

  String get _key => '$_keyPrefix$_userEmail';

  static Future<JobApplicationRepository?> create(String? userEmail) async {
    if (userEmail == null || userEmail.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return JobApplicationRepository(prefs, userEmail);
  }

  Future<List<JobApplication>> fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => JobApplication.fromJson(item.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
  }

  Future<bool> hasApplied(String postId) async {
    final items = await fetchAll();
    return items.any((item) => item.postId == postId);
  }

  Future<void> add(JobApplication application) async {
    final items = await fetchAll();
    if (items.any((item) => item.postId == application.postId)) return;
    items.insert(0, application);
    await _save(items);
  }

  Future<void> removeByPostId(String postId) async {
    final items = await fetchAll();
    final next = items.where((item) => item.postId != postId).toList();
    if (next.length == items.length) return;
    await _save(next);
  }

  Future<void> _save(List<JobApplication> items) async {
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await _prefs.setString(_key, encoded);
  }
}
