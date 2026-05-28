import 'package:map/features/auth/domain/validators/email_validator.dart';
import 'package:map/features/auth/domain/validators/name_validator.dart';
import 'package:map/features/auth/domain/validators/password_confirm_validator.dart';
import 'package:map/features/auth/domain/validators/password_validator.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';

/// 회원가입 폼 검증
class ValidateSignUpFormUseCase {
  const ValidateSignUpFormUseCase();

  SignUpValidationResult call({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String passwordConfirm,
  }) {
    final nameResult = NameValidator.validate(name);
    final phoneResult = PhoneValidator.validate(phone);
    final emailResult = EmailValidator.validate(email);
    final passwordResult = PasswordValidator.validate(password);
    final confirmResult = PasswordConfirmValidator.validate(
      password: password,
      confirm: passwordConfirm,
    );

    final isValid = nameResult.isValid &&
        phoneResult.isValid &&
        emailResult.isValid &&
        passwordResult.isValid &&
        confirmResult.isValid;

    return SignUpValidationResult(
      isValid: isValid,
      nameError: nameResult.message,
      phoneError: phoneResult.message,
      emailError: emailResult.message,
      passwordError: passwordResult.message,
      passwordConfirmError: confirmResult.message,
    );
  }
}

class SignUpValidationResult {
  const SignUpValidationResult({
    required this.isValid,
    this.nameError,
    this.phoneError,
    this.emailError,
    this.passwordError,
    this.passwordConfirmError,
  });

  final bool isValid;
  final String? nameError;
  final String? phoneError;
  final String? emailError;
  final String? passwordError;
  final String? passwordConfirmError;

  String? get firstError =>
      nameError ??
      phoneError ??
      emailError ??
      passwordError ??
      passwordConfirmError;
}
