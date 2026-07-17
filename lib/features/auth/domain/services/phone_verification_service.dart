import 'package:meta/meta.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/auth/domain/services/mock_phone_verification_service.dart';

/// 휴대폰 인증 용도
enum PhoneVerificationPurpose {
  signup('signup'),
  findEmail('find_email'),
  resetPassword('reset_password');

  const PhoneVerificationPurpose(this.apiValue);
  final String apiValue;
}

class PhoneVerifyResult {
  const PhoneVerifyResult({
    required this.verified,
    this.phoneVerifiedToken,
    this.errorMessage,
  });

  final bool verified;
  final String? phoneVerifiedToken;

  /// 실패 시 서버가 내려준 구체적인 사유 (없으면 호출부의 기본 문구 사용)
  final String? errorMessage;
}

/// 휴대폰 인증 — API 연동 또는 로컬 mock
abstract class PhoneVerificationService {
  factory PhoneVerificationService() {
    if (EnvConfig.isComplianceApiEnabled) {
      return RemotePhoneVerificationService();
    }
    return _MockPhoneVerificationAdapter();
  }

  /// Widget/단위 테스트용 — 항상 로컬 mock OTP
  @visibleForTesting
  factory PhoneVerificationService.localMock() => _MockPhoneVerificationAdapter();

  Future<String> sendCode(String phone);
  Future<PhoneVerifyResult> verifyAsync(
    String phone,
    String code, {
    PhoneVerificationPurpose purpose = PhoneVerificationPurpose.signup,
  });
  void clear();
  bool get hasPendingCode;
  String? get pendingPhone;
  String? get lastPhoneVerifiedToken;
}

class _MockPhoneVerificationAdapter implements PhoneVerificationService {
  final _mock = MockPhoneVerificationService.instance;
  String? _lastToken;

  @override
  bool get hasPendingCode => _mock.hasPendingCode;

  @override
  String? get pendingPhone => _mock.pendingPhone;

  @override
  String? get lastPhoneVerifiedToken => _lastToken;

  @override
  Future<String> sendCode(String phone) => _mock.sendCode(phone);

  @override
  Future<PhoneVerifyResult> verifyAsync(
    String phone,
    String code, {
    PhoneVerificationPurpose purpose = PhoneVerificationPurpose.signup,
  }) async {
    final ok = _mock.verify(phone, code);
    if (!ok) {
      return const PhoneVerifyResult(verified: false);
    }
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    _lastToken = _mock.issueLocalVerifiedToken(
      phone: normalized,
      purpose: purpose.apiValue,
    );
    return PhoneVerifyResult(verified: true, phoneVerifiedToken: _lastToken);
  }

  @override
  void clear() {
    _lastToken = null;
    _mock.clear();
  }
}

class RemotePhoneVerificationService implements PhoneVerificationService {
  final _client = IljariApiClient();
  String? _pendingPhone;
  String? _lastToken;

  @override
  bool get hasPendingCode => _pendingPhone != null;

  @override
  String? get pendingPhone => _pendingPhone;

  @override
  String? get lastPhoneVerifiedToken => _lastToken;

  @override
  Future<String> sendCode(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final result = await _client.sendPhoneVerificationCode(normalized);
    _pendingPhone = normalized;
    final devCode = result['dev_code'] as String?;
    return devCode ?? '******';
  }

  @override
  Future<PhoneVerifyResult> verifyAsync(
    String phone,
    String code, {
    PhoneVerificationPurpose purpose = PhoneVerificationPurpose.signup,
  }) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (_pendingPhone != normalized) {
      return const PhoneVerifyResult(verified: false);
    }
    try {
      final result = await _client.verifyPhoneCode(
        phone: normalized,
        code: code,
        purpose: purpose.apiValue,
      );
      final token = result['phone_verified_token'] as String?;
      _lastToken = token;
      return PhoneVerifyResult(verified: true, phoneVerifiedToken: token);
    } on IljariApiException catch (error) {
      return PhoneVerifyResult(verified: false, errorMessage: error.message);
    } on Object {
      return const PhoneVerifyResult(verified: false);
    }
  }

  @override
  void clear() {
    _pendingPhone = null;
    _lastToken = null;
  }
}
