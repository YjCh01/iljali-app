import 'dart:convert';

import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/datasources/closed_ghost_pin_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_pin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QC·데모 시드가 실서비스 로컬 스토리지에 섞이지 않도록 정리
abstract final class QcLocalStoragePurge {
  static const qcCompanyKeys = {'1000000001', '1000000002'};
  static const qcEmailDomain = '@qc.iljari.co.kr';
  static const _seekerAccountsKey = 'local_individual_accounts_v1';

  static bool isQcCompanyKey(String? key) {
    if (key == null || key.isEmpty) return false;
    return qcCompanyKeys.contains(key.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static bool isQcEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return email.toLowerCase().contains(qcEmailDomain);
  }

  static bool isQcPostId(String? id) {
    if (id == null || id.isEmpty) return false;
    return id.startsWith('qc_');
  }

  static bool isQcJobPost(CorporateJobPost post) {
    if (isQcPostId(post.id)) return true;
    final companyKey = post.registeredBy?.companyKey;
    if (isQcCompanyKey(companyKey)) return true;
    if (isQcEmail(post.recruiterEmail)) return true;
    return false;
  }

  static bool isQcGhostPin(ClosedGhostPin pin) {
    if (pin.id.startsWith('ghost_qc_')) return true;
    return isQcPostId(pin.sourcePostId);
  }

  /// QC_MODE=false 실서비스 빌드에서 1회성 정리
  static Future<Map<String, int>> purgeProductionArtifacts() async {
    if (EnvConfig.qcMode) return const {};

    final counts = <String, int>{
      'wallet_keys': 0,
      'bonus_ledger_keys': 0,
      'seeker_accounts': 0,
      'ghost_pins': 0,
      'in_memory_posts': 0,
    };

    final prefs = await SharedPreferences.getInstance();
    counts['wallet_keys'] = await _purgeJsonMapKeys(
      prefs,
      'employer_push_wallets_v1',
      isQcCompanyKey,
    );
    counts['bonus_ledger_keys'] = await _purgeJsonMapKeys(
      prefs,
      'company_bonus_ledger_v1',
      isQcCompanyKey,
    );
    counts['seeker_accounts'] = await _purgeQcSeekerAccounts(prefs);

    final ghostPins = await const ClosedGhostPinLocalDataSourceImpl().fetchAll();
    final filtered =
        ghostPins.where((pin) => !isQcGhostPin(pin)).toList(growable: false);
    if (filtered.length != ghostPins.length) {
      counts['ghost_pins'] = ghostPins.length - filtered.length;
      ClosedGhostPinLocalDataSourceImpl.replaceFromServer(filtered);
    }

    final posts =
        await const CorporateJobPostLocalDataSourceImpl().fetchJobPosts();
    final realPosts =
        posts.where((post) => !isQcJobPost(post)).toList(growable: false);
    if (realPosts.length != posts.length) {
      counts['in_memory_posts'] = posts.length - realPosts.length;
      CorporateJobPostLocalDataSourceImpl.replaceFromServer(realPosts);
    }

    return counts;
  }

  static Future<int> _purgeQcSeekerAccounts(SharedPreferences prefs) async {
    final raw = prefs.getString(_seekerAccountsKey);
    if (raw == null || raw.isEmpty) return 0;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return 0;
    final kept = <dynamic>[];
    var removed = 0;
    for (final item in decoded) {
      if (item is! Map) {
        kept.add(item);
        continue;
      }
      final email = '${item['email'] ?? ''}';
      if (isQcEmail(email)) {
        removed++;
        continue;
      }
      kept.add(item);
    }
    if (removed == 0) return 0;
    await prefs.setString(_seekerAccountsKey, jsonEncode(kept));
    return removed;
  }

  static Future<int> _purgeJsonMapKeys(
    SharedPreferences prefs,
    String storageKey,
    bool Function(String key) shouldRemove,
  ) async {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return 0;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 0;
    final next = <String, dynamic>{};
    var removed = 0;
    for (final entry in decoded.entries) {
      final key = '${entry.key}';
      if (shouldRemove(key)) {
        removed++;
        continue;
      }
      next[key] = entry.value;
    }
    if (removed == 0) return 0;
    await prefs.setString(storageKey, jsonEncode(next));
    return removed;
  }
}
