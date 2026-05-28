import 'dart:convert';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사업자번호(BRN)당 신규 보너스 1회 지급 원장
class CompanyBonusLedgerRepository {
  CompanyBonusLedgerRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'company_bonus_ledger_v1';

  static Future<CompanyBonusLedgerRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CompanyBonusLedgerRepository(prefs);
  }

  Future<bool> isSignupBonusClaimed(String companyKey) async {
    final all = _loadAll();
    return all[companyKey]?['claimed'] as bool? ?? false;
  }

  /// 최초 1회만 true — 보너스 지급 가능
  Future<bool> tryClaimSignupBonus(String companyKey) async {
    final all = _loadAll();
    final existing = all[companyKey];
    if (existing?['claimed'] == true) return false;
    all[companyKey] = {
      'claimed': true,
      'claimedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(_key, jsonEncode(all));
    return true;
  }

  Map<String, Map<String, dynamic>> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
      (k, v) => MapEntry(
        '$k',
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
      ),
    );
  }
}

extension CompanyBonusGrant on CompanyBonusLedgerRepository {
  static int get grantCount => PushPackageCatalog.signupBonusPushes;
}
