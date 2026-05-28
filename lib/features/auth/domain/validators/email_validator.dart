import 'package:map/features/auth/domain/validators/validation_result.dart';

/// 이메일 형식 검증
abstract final class EmailValidator {
  static final RegExp _pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static ValidationResult validate(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return const ValidationResult.invalid('이메일을 입력해 주세요.');
    }
    if (!email.contains('@')) {
      return const ValidationResult.invalid('이메일에 @가 포함되어야 합니다.');
    }
    if (!_pattern.hasMatch(email)) {
      return const ValidationResult.invalid('올바른 이메일 형식이 아닙니다.');
    }
    return const ValidationResult.valid();
  }
}
