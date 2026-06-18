/// MVP 휴대폰 인증 — 로컬 mock (실서비스 SMS 연동 전)
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
  }
}
