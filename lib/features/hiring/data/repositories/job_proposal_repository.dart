import 'dart:convert';

import 'package:map/features/hiring/domain/entities/job_proposal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 채용 제안 로컬 저장소
class JobProposalRepository {
  JobProposalRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'job_proposals_v1';

  static Future<JobProposalRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return JobProposalRepository(prefs);
  }

  Future<List<JobProposal>> fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => JobProposal.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on Object {
      return [];
    }
  }

  Future<List<JobProposal>> fetchForCompany(String companyKey) async {
    final normalized = companyKey.trim();
    if (normalized.isEmpty) return [];
    return (await fetchAll())
        .where((p) => p.companyKey == normalized)
        .toList();
  }

  Future<List<JobProposal>> fetchForSeeker(String seekerEmail) async {
    final normalized = seekerEmail.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    return (await fetchAll())
        .where((p) => p.seekerEmail.trim().toLowerCase() == normalized)
        .toList();
  }

  Future<List<JobProposal>> fetchPendingForSeeker(String seekerEmail) async {
    return (await fetchForSeeker(seekerEmail))
        .where((p) => p.isPending)
        .toList();
  }

  Future<bool> hasPending({
    required String postId,
    required String seekerEmail,
  }) async {
    final normalizedEmail = seekerEmail.trim().toLowerCase();
    return (await fetchAll()).any(
      (p) =>
          p.postId == postId &&
          p.seekerEmail.trim().toLowerCase() == normalizedEmail &&
          p.isPending,
    );
  }

  Future<void> save(JobProposal proposal) async {
    final items = await fetchAll();
    final index = items.indexWhere((p) => p.id == proposal.id);
    if (index == -1) {
      items.insert(0, proposal);
    } else {
      items[index] = proposal;
    }
    await _persist(items);
  }

  Future<void> updateStatus({
    required String proposalId,
    required JobProposalStatus status,
  }) async {
    final items = await fetchAll();
    final index = items.indexWhere((p) => p.id == proposalId);
    if (index == -1) return;
    items[index] = items[index].copyWith(
      status: status,
      respondedAt: DateTime.now(),
    );
    await _persist(items);
  }

  Future<void> _persist(List<JobProposal> items) async {
    await _prefs.setString(
      _key,
      jsonEncode(items.map((p) => p.toJson()).toList()),
    );
  }
}
