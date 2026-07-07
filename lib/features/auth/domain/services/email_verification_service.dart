import 'package:meta/meta.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';

/// 이메일 인증 용도
enum EmailVerificationPurpose {
  findEmail('find_email'),
  resetPassword('reset_password');

  const EmailVerificationPurpose(this.apiValue);
  final String apiValue;
}

class EmailVerifyResult {
  const EmailVerifyResult({
    required this.verified,
    this.emailVerifiedToken,
  });

  final bool verified;
  final String? emailVerifiedToken;
}

abstract class EmailVerificationService {
  factory EmailVerificationService() {
    if (EnvConfig.isComplianceApiEnabled) {
      return RemoteEmailVerificationService();
    }
    return _MockEmailVerificationAdapter();
  }

  @visibleForTesting
  factory EmailVerificationService.localMock() => _MockEmailVerificationAdapter();

  Future<String> sendCode(String email);
  Future<EmailVerifyResult> verifyAsync(
    String email,
    String code, {
    EmailVerificationPurpose purpose = EmailVerificationPurpose.findEmail,
  });
  void clear();
}

class _MockEmailVerificationAdapter implements EmailVerificationService {
  String? _pendingEmail;
  String? _pendingCode;
  String? _lastToken;

  @override
  Future<String> sendCode(String email) async {
    final normalized = email.trim().toLowerCase();
    _pendingEmail = normalized;
    _pendingCode = '123456';
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _pendingCode!;
  }

  @override
  Future<EmailVerifyResult> verifyAsync(
    String email,
    String code, {
    EmailVerificationPurpose purpose = EmailVerificationPurpose.findEmail,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_pendingEmail != normalized || code.trim() != _pendingCode) {
      return const EmailVerifyResult(verified: false);
    }
    _lastToken = 'mock_email_token_${purpose.apiValue}_$normalized';
    return EmailVerifyResult(verified: true, emailVerifiedToken: _lastToken);
  }

  @override
  void clear() {
    _pendingEmail = null;
    _pendingCode = null;
    _lastToken = null;
  }
}

class RemoteEmailVerificationService implements EmailVerificationService {
  final IljariApiClient _client = IljariApiClient();

  @override
  Future<String> sendCode(String email) async {
    final result = await _client.sendEmailVerificationCode(email);
    final devCode = result['dev_code'] as String?;
    return devCode ?? '******';
  }

  @override
  Future<EmailVerifyResult> verifyAsync(
    String email,
    String code, {
    EmailVerificationPurpose purpose = EmailVerificationPurpose.findEmail,
  }) async {
    final result = await _client.verifyEmailCode(
      email: email,
      code: code,
      purpose: purpose.apiValue,
    );
    final verified = result['verified'] == true;
    return EmailVerifyResult(
      verified: verified,
      emailVerifiedToken: result['email_verified_token'] as String?,
    );
  }

  @override
  void clear() {}
}
