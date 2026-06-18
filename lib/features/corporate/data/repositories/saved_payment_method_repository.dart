import 'dart:convert';

import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사업자번호 단위 저장 카드 목록 (MVP — 로컬, 추후 PG 서버 vault)
class SavedPaymentMethodRepository {
  SavedPaymentMethodRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'saved_payment_methods_v1';

  static Future<SavedPaymentMethodRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SavedPaymentMethodRepository(prefs);
  }

  Map<String, List<SavedPaymentMethod>> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((companyKey, value) {
      if (value is! List) return MapEntry('$companyKey', <SavedPaymentMethod>[]);
      final methods = value
          .whereType<Map>()
          .map((item) => SavedPaymentMethod.fromJson(item.cast<String, dynamic>()))
          .toList();
      return MapEntry('$companyKey', methods);
    });
  }

  Future<void> _saveAll(Map<String, List<SavedPaymentMethod>> all) async {
    final encoded = all.map(
      (key, methods) => MapEntry(key, methods.map((m) => m.toJson()).toList()),
    );
    await _prefs.setString(_key, jsonEncode(encoded));
  }

  Future<List<SavedPaymentMethod>> listForCompany(String companyKey) async {
    final key = companyKey.trim();
    if (key.isEmpty) return [];
    final methods = List<SavedPaymentMethod>.from(_loadAll()[key] ?? const []);
    methods.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return b.registeredAt.compareTo(a.registeredAt);
    });
    return methods;
  }

  Future<SavedPaymentMethod?> findDefault(String companyKey) async {
    final methods = await listForCompany(companyKey);
    for (final method in methods) {
      if (method.isDefault) return method;
    }
    return methods.isEmpty ? null : methods.first;
  }

  Future<SavedPaymentMethod?> findById({
    required String companyKey,
    required String id,
  }) async {
    for (final method in await listForCompany(companyKey)) {
      if (method.id == id) return method;
    }
    return null;
  }

  Future<SavedPaymentMethod> add(SavedPaymentMethod method) async {
    final key = method.companyKey.trim();
    final all = _loadAll();
    final list = List<SavedPaymentMethod>.from(all[key] ?? const []);
    final makeDefault = list.isEmpty || method.isDefault;
    if (makeDefault) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isDefault: false);
      }
    }
    list.add(method.copyWith(isDefault: makeDefault));
    all[key] = list;
    await _saveAll(all);
    return list.last;
  }

  Future<bool> remove({
    required String companyKey,
    required String id,
  }) async {
    final key = companyKey.trim();
    final all = _loadAll();
    final list = List<SavedPaymentMethod>.from(all[key] ?? const []);
    final before = list.length;
    list.removeWhere((m) => m.id == id);
    if (list.length == before) return false;
    if (list.isNotEmpty && !list.any((m) => m.isDefault)) {
      list[0] = list[0].copyWith(isDefault: true);
    }
    all[key] = list;
    await _saveAll(all);
    return true;
  }

  Future<bool> setDefault({
    required String companyKey,
    required String id,
  }) async {
    final key = companyKey.trim();
    final all = _loadAll();
    final list = List<SavedPaymentMethod>.from(all[key] ?? const []);
    var found = false;
    for (var i = 0; i < list.length; i++) {
      final isTarget = list[i].id == id;
      if (isTarget) found = true;
      list[i] = list[i].copyWith(isDefault: isTarget);
    }
    if (!found) return false;
    all[key] = list;
    await _saveAll(all);
    return true;
  }
}
