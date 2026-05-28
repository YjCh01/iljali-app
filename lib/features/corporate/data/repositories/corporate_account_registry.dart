import 'dart:convert';

import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/utils/corporate_handler_code_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기업(사업자번호)별 하위 담당자 계정 mock 레지스트리
class CorporateAccountRegistry {
  CorporateAccountRegistry(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'corporate_handler_accounts';

  static Future<CorporateAccountRegistry> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CorporateAccountRegistry(prefs);
  }

  String companyKey(String businessRegistrationNumber) =>
      businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');

  Future<List<Map<String, String>>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry('$k', '$v')))
        .toList();
  }

  Future<void> _saveAll(List<Map<String, String>> rows) async {
    await _prefs.setString(_key, jsonEncode(rows));
  }

  Future<List<String>> existingCodesForCompany(String businessRegistrationNumber) async {
    final key = companyKey(businessRegistrationNumber);
    final rows = await _loadAll();
    return rows
        .where((row) => row['companyKey'] == key)
        .map((row) => row['handlerCode'] ?? '')
        .where((code) => code.length == 4)
        .toList();
  }

  Future<CorporateMemberProfile> registerHandler({
    required String companyName,
    required String businessRegistrationNumber,
    required String department,
    required String contactPersonName,
  }) async {
    final key = companyKey(businessRegistrationNumber);
    final existing = await existingCodesForCompany(businessRegistrationNumber);
    final handlerCode = CorporateHandlerCodeGenerator.nextCode(existing);

    final rows = await _loadAll();
    rows.add({
      'companyKey': key,
      'companyName': companyName.trim(),
      'businessRegistrationNumber':
          businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), ''),
      'department': department.trim(),
      'contactPersonName': contactPersonName.trim(),
      'handlerCode': handlerCode,
      'registeredAt': DateTime.now().toIso8601String(),
    });
    await _saveAll(rows);

    return CorporateMemberProfile(
      companyName: companyName.trim(),
      businessRegistrationNumber:
          businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), ''),
      department: department.trim(),
      contactPersonName: contactPersonName.trim(),
      handlerCode: handlerCode,
    );
  }
}
