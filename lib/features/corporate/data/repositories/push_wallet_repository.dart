import 'dart:convert';

import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushWalletRepository {
  PushWalletRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'employer_push_wallets_v1';

  static Future<PushWalletRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PushWalletRepository(prefs);
  }

  Future<EmployerPushWallet> load(String companyKey) async {
    final all = await _loadAll();
    final raw = all[companyKey];
    if (raw == null) return EmployerPushWallet.initial();
    return EmployerPushWallet.fromJson(raw);
  }

  Future<void> save(String companyKey, EmployerPushWallet wallet) async {
    final all = await _loadAll();
    all[companyKey] = wallet.toJson();
    await _prefs.setString(_key, jsonEncode(all));
  }

  Future<Map<String, Map<String, dynamic>>> _loadAll() async {
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
