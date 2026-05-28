import 'dart:convert';

import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/utils/branch_hierarchy_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalBranchRepository {
  LocalBranchRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'corporate_branches_v1';

  static Future<LocalBranchRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalBranchRepository(prefs);
    await repo._purgePersistedDemoBranches();
    return repo;
  }

  Future<List<CorporateBranch>> fetchForCompany(String companyKey) async {
    final all = await _loadAll();
    return all
        .where((b) => b.companyKey == companyKey && b.isActive)
        .toList()
      ..sort((a, b) {
        final levelCmp = a.level.sortOrder.compareTo(b.level.sortOrder);
        if (levelCmp != 0) return levelCmp;
        return (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0));
      });
  }

  Future<CorporateBranch?> findById(String branchId) async {
    final all = await _loadAll();
    for (final b in all) {
      if (b.id == branchId) return b;
    }
    return null;
  }

  Future<CorporateBranch> createBranch({
    required String companyKey,
    required String name,
    required String roadAddress,
    BranchLevel level = BranchLevel.store,
    String? parentBranchId,
    String? managerName,
    String? managerHandlerCode,
  }) async {
    final existing = await fetchForCompany(companyKey);
    final validationError = BranchHierarchyValidator.validateCreate(
      level: level,
      parentBranchId: parentBranchId,
      existing: existing,
    );
    if (validationError != null) {
      throw BranchHierarchyException(validationError);
    }

    final branch = CorporateBranch(
      id: 'branch_${DateTime.now().millisecondsSinceEpoch}',
      companyKey: companyKey,
      name: name.trim(),
      roadAddress: roadAddress.trim(),
      level: level,
      parentBranchId: parentBranchId,
      managerName: managerName,
      managerHandlerCode: managerHandlerCode,
      createdAt: DateTime.now(),
    );
    final all = await _loadAll();
    all.add(branch);
    await _saveAll(all);
    return branch;
  }

  Future<void> deactivate(String branchId) async {
    final all = await _loadAll();
    final index = all.indexWhere((b) => b.id == branchId);
    if (index < 0) return;
    all[index] = all[index].copyWith(isActive: false);
    await _saveAll(all);
  }

  Future<void> _purgePersistedDemoBranches() async {
    final all = await _loadAll();
    final cleaned = all.where((b) => !b.id.startsWith('demo_')).toList();
    if (cleaned.length == all.length) return;
    await _saveAll(cleaned);
  }

  Future<List<CorporateBranch>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => CorporateBranch.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveAll(List<CorporateBranch> branches) async {
    await _prefs.setString(
      _key,
      jsonEncode(branches.map((e) => e.toJson()).toList()),
    );
  }
}

class BranchHierarchyException implements Exception {
  BranchHierarchyException(this.message);
  final String message;
  @override
  String toString() => message;
}
