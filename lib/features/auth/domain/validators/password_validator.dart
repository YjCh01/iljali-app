import 'package:map/features/auth/domain/validators/validation_result.dart';

/// 비밀번호 검증
abstract final class PasswordValidator {
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _special = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]');

  /// 로그인 — 입력 여부만 확인
  static ValidationResult validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('비밀번호를 입력해 주세요.');
    }
    return const ValidationResult.valid();
  }

  /// 회원가입 — 복잡도 규칙 포함
  static ValidationResult validate(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return const ValidationResult.invalid('비밀번호를 입력해 주세요.');
    }
    if (password.length < 8) {
      return const ValidationResult.invalid('비밀번호는 8자리 이상이어야 합니다.');
    }

    final hasDigit = _digit.hasMatch(password);
    final hasUpper = _upper.hasMatch(password);
    final hasLower = _lower.hasMatch(password);
    final hasSpecial = _special.hasMatch(password);

    final typeCount = [hasDigit, hasUpper, hasLower, hasSpecial]
        .where((included) => included)
        .length;

    if (typeCount < 1) {
      return const ValidationResult.invalid(
        '비밀번호에 숫자, 영문 대·소문자, 특수문자 중 1가지 이상 포함해 주세요.',
      );
    }

    return const ValidationResult.valid();
  }
}
