import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
class MockPhoneVerificationService {
  MockPhoneVerificationService._();
  static final instance = MockPhoneVerificationService._();

  String? _pendingPhone;
  String? _pendingCode;
  DateTime? _sentAt;

  static const devBypassCode = '123456';
  static const codeTtl = Duration(minutes: 3);

  bool get hasPendingCode =>
      _pendingPhone != null &&
      _pendingCode != null &&
      _sentAt != null &&
      DateTime.now().difference(_sentAt!) < codeTtl;

  String? get pendingPhone => _pendingPhone;

  /// 인증번호 발송 (mock)
  Future<String> sendCode(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    _pendingPhone = normalized;
    _pendingCode = devBypassCode;
    _sentAt = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _pendingCode!;
  }

  /// 인증 확인
  bool verify(String phone, String code) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!hasPendingCode) return false;
    if (_pendingPhone != normalized) return false;
    if (code.trim() != _pendingCode) return false;
    return true;
  }

  void clear() {
    _pendingPhone = null;
    _pendingCode = null;
    _sentAt = null;
    _verifiedTokens.clear();
  }

  final _verifiedTokens = <String, String>{};

  /// 로컬 mock용 phone_verified_token (API 미연동 시 가입·찾기·재설정 바인딩)
  String issueLocalVerifiedToken({
    required String phone,
    required String purpose,
  }) {
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final digest = sha256.convert(utf8.encode('$phone::$purpose::${base64Url.encode(nonce)}'));
    final token = base64Url.encode(utf8.encode('${phone}|$purpose|${digest.toString()}'));
    _verifiedTokens['$phone::$purpose'] = token;
    return token;
  }

  String? readLocalVerifiedToken({
    required String phone,
    required String purpose,
  }) {
    return _verifiedTokens['$phone::$purpose'];
  }
}
