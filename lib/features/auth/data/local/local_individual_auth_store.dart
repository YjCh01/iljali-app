import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// API 미연동 시 로컬 개인회원 계정 저장소
abstract final class LocalIndividualAuthStore {
  static const _key = 'local_individual_accounts_v1';

  static Future<List<Map<String, dynamic>>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Object {
      return [];
    }
  }

  static Future<void> _saveAll(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rows));
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  static String _hashPassword(String password, String salt) {
    final digest = sha256.convert(utf8.encode('$salt::$password'));
    return digest.toString();
  }

  static String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required SeekerMemberProfile seekerProfile,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPhone = _normalizePhone(phone);
    final rows = await _loadAll();

    if (rows.any((row) => _normalizeEmail(row['email'] as String) == normalizedEmail)) {
      throw StateError('이미 사용 중인 이메일입니다.');
    }
    if (rows.any((row) => _normalizePhone(row['phone'] as String) == normalizedPhone)) {
      throw StateError('이미 가입된 휴대폰 번호입니다.');
    }

    final salt = _newSalt();
    rows.add({
      'email': normalizedEmail,
      'displayName': displayName.trim(),
      'phone': normalizedPhone,
      'salt': salt,
      'passwordHash': _hashPassword(password, salt),
      'seekerProfile': seekerProfile.toJson(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _saveAll(rows);
  }

  static Future<Map<String, dynamic>?> authenticate({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final rows = await _loadAll();
    for (final row in rows) {
      if (_normalizeEmail(row['email'] as String) != normalizedEmail) continue;
      final salt = row['salt'] as String? ?? '';
      final expected = row['passwordHash'] as String? ?? '';
      if (_hashPassword(password, salt) != expected) return null;
      return row;
    }
    return null;
  }

  static Future<List<String>> findMaskedEmailsByPhone(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    final rows = await _loadAll();
    final emails = rows
        .where((row) => _normalizePhone(row['phone'] as String) == normalizedPhone)
        .map((row) => _maskEmail(row['email'] as String))
        .toList();
    return emails;
  }

  static Future<bool> resetPassword({
    required String email,
    required String phone,
    required String newPassword,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPhone = _normalizePhone(phone);
    final rows = await _loadAll();
    var updated = false;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_normalizeEmail(row['email'] as String) != normalizedEmail) continue;
      if (_normalizePhone(row['phone'] as String) != normalizedPhone) continue;
      final salt = _newSalt();
      rows[i] = {
        ...row,
        'salt': salt,
        'passwordHash': _hashPassword(newPassword, salt),
      };
      updated = true;
      break;
    }
    if (!updated) return false;
    await _saveAll(rows);
    return true;
  }

  static String _maskEmail(String email) {
    if (!email.contains('@')) return '***';
    final parts = email.split('@');
    final local = parts.first;
    final domain = parts.sublist(1).join('@');
    if (local.length <= 2) {
      return '${local[0]}*@$domain';
    }
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  static Future<List<Map<String, dynamic>>> listAllAccounts() async =>
      _loadAll();

  static Future<void> updateSeekerProfile({
    required String email,
    required SeekerMemberProfile seekerProfile,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final rows = await _loadAll();
    var updated = false;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_normalizeEmail(row['email'] as String) != normalizedEmail) continue;
      rows[i] = {
        ...row,
        'seekerProfile': seekerProfile.toJson(),
      };
      updated = true;
      break;
    }
    if (!updated) return;
    await _saveAll(rows);
  }

  static Future<SeekerMemberProfile?> seekerProfileForEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final rows = await _loadAll();
    for (final row in rows) {
      if (_normalizeEmail(row['email'] as String) != normalizedEmail) continue;
      final raw = row['seekerProfile'];
      if (raw is Map<String, dynamic>) {
        return SeekerMemberProfile.fromJson(raw);
      }
      if (raw is Map) {
        return SeekerMemberProfile.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }
    return null;
  }

  static Future<String?> displayNameForEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final rows = await _loadAll();
    for (final row in rows) {
      if (_normalizeEmail(row['email'] as String) != normalizedEmail) continue;
      final name = row['displayName'] as String? ?? '';
      return name.trim().isEmpty ? null : name.trim();
    }
    return null;
  }

  static Future<void> updateDisplayName({
    required String email,
    required String displayName,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final rows = await _loadAll();
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_normalizeEmail(row['email'] as String) != normalizedEmail) continue;
      rows[i] = {
        ...row,
        'displayName': displayName.trim(),
      };
      await _saveAll(rows);
      return;
    }
  }
}
