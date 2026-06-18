import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 구직자 신분증·통장사본 (이메일별 로컬 저장)
class SeekerDocumentRepository {
  SeekerDocumentRepository(this._prefs);

  static const _key = 'seeker_documents_v1';

  final SharedPreferences _prefs;

  static Future<SeekerDocumentRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerDocumentRepository(prefs);
  }

  Future<SeekerDocuments> load(String seekerEmail) async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const SeekerDocuments();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = map[seekerEmail.trim().toLowerCase()];
      if (entry is! Map) return const SeekerDocuments();
      return SeekerDocuments.fromJson(Map<String, dynamic>.from(entry));
    } catch (_) {
      return const SeekerDocuments();
    }
  }

  Future<void> save(String seekerEmail, SeekerDocuments docs) async {
    final raw = _prefs.getString(_key);
    final map = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          map.addAll(decoded.map((k, v) => MapEntry('$k', v)));
        }
      } catch (_) {}
    }
    map[seekerEmail.trim().toLowerCase()] = docs.toJson();
    await _prefs.setString(_key, jsonEncode(map));
  }
}

class SeekerDocuments {
  const SeekerDocuments({
    this.idCardImagePath,
    this.bankAccountImagePath,
    this.updatedAt,
  });

  final String? idCardImagePath;
  final String? bankAccountImagePath;
  final DateTime? updatedAt;

  bool get hasIdCard =>
      idCardImagePath != null && idCardImagePath!.trim().isNotEmpty;

  bool get hasBankAccount =>
      bankAccountImagePath != null && bankAccountImagePath!.trim().isNotEmpty;

  SeekerDocuments copyWith({
    String? idCardImagePath,
    String? bankAccountImagePath,
    DateTime? updatedAt,
  }) {
    return SeekerDocuments(
      idCardImagePath: idCardImagePath ?? this.idCardImagePath,
      bankAccountImagePath: bankAccountImagePath ?? this.bankAccountImagePath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        if (idCardImagePath != null) 'idCardImagePath': idCardImagePath,
        if (bankAccountImagePath != null)
          'bankAccountImagePath': bankAccountImagePath,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory SeekerDocuments.fromJson(Map<String, dynamic> json) {
    return SeekerDocuments(
      idCardImagePath: json['idCardImagePath'] as String?,
      bankAccountImagePath: json['bankAccountImagePath'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
