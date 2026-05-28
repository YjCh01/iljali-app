import 'package:map/features/auth/domain/validators/email_validator.dart';
import 'package:map/features/auth/domain/validators/password_validator.dart';

/// 로그인 폼 검증
class ValidateLoginFormUseCase {
  const ValidateLoginFormUseCase();

  LoginValidationResult call({
    required String email,
    required String password,
  }) {
    final emailResult = EmailValidator.validate(email);
    final passwordResult = PasswordValidator.validateRequired(password);

    return LoginValidationResult(
      isValid: emailResult.isValid && passwordResult.isValid,
      emailError: emailResult.message,
      passwordError: passwordResult.message,
    );
  }
}

class LoginValidationResult {
  const LoginValidationResult({
    required this.isValid,
    this.emailError,
    this.passwordError,
  });

  final bool isValid;
  final String? emailError;
  final String? passwordError;

  String? get firstError => emailError ?? passwordError;
}
