import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:map/features/corporate/domain/entities/corporate_tax_document.dart';

class CorporateTaxDocumentRepository {
  CorporateTaxDocumentRepository(this._prefs);

  static const _key = 'corporate_tax_documents_v1';

  final SharedPreferences _prefs;

  static Future<CorporateTaxDocumentRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CorporateTaxDocumentRepository(prefs);
  }

  Future<List<CorporateTaxDocument>> listForCompany(String companyKey) async {
    final all = await _loadAll();
    return all
        .where((doc) => doc.companyKey == companyKey)
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  Future<List<CorporateTaxDocument>> listForOrder(String orderId) async {
    final all = await _loadAll();
    return all.where((doc) => doc.orderId == orderId).toList();
  }

  Future<void> saveAll(List<CorporateTaxDocument> documents) async {
    final all = await _loadAll();
    final ids = documents.map((d) => d.id).toSet();
    final merged = [
      ...all.where((d) => !ids.contains(d.id)),
      ...documents,
    ];
    await _persist(merged);
  }

  Future<List<CorporateTaxDocument>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CorporateTaxDocument.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<CorporateTaxDocument> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, encoded);
  }
}
