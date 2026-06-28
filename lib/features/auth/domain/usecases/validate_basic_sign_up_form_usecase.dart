import 'package:map/features/auth/domain/validators/email_validator.dart';
import 'package:map/features/auth/domain/validators/password_confirm_validator.dart';
import 'package:map/features/auth/domain/validators/password_validator.dart';

/// 개인회원 1단계 가입 — 이메일(아이디)·비밀번호만 검증
class ValidateBasicSignUpFormUseCase {
  const ValidateBasicSignUpFormUseCase();

  BasicSignUpValidationResult call({
    required String email,
    required String password,
    required String passwordConfirm,
  }) {
    final emailResult = EmailValidator.validate(email);
    final passwordResult = PasswordValidator.validate(password);
    final confirmResult = PasswordConfirmValidator.validate(
      password: password,
      confirm: passwordConfirm,
    );

    final isValid = emailResult.isValid &&
        passwordResult.isValid &&
        confirmResult.isValid;

    return BasicSignUpValidationResult(
      isValid: isValid,
      emailError: emailResult.message,
      passwordError: passwordResult.message,
      passwordConfirmError: confirmResult.message,
    );
  }
}

class BasicSignUpValidationResult {
  const BasicSignUpValidationResult({
    required this.isValid,
    this.emailError,
    this.passwordError,
    this.passwordConfirmError,
  });

  final bool isValid;
  final String? emailError;
  final String? passwordError;
  final String? passwordConfirmError;
}

String displayNameFromEmail(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '구직자';
  return local;
}
