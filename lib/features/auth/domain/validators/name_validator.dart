import 'package:map/features/auth/domain/validators/validation_result.dart';

/// 이름 검증
abstract final class NameValidator {
  static ValidationResult validate(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return const ValidationResult.invalid('이름을 입력해 주세요.');
    }
    if (name.length < 2) {
      return const ValidationResult.invalid('이름은 2자 이상 입력해 주세요.');
    }
    return const ValidationResult.valid();
  }
}
