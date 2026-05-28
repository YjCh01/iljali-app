import 'package:map/features/auth/domain/validators/validation_result.dart';

/// 비밀번호 확인 검증
abstract final class PasswordConfirmValidator {
  static ValidationResult validate({
    required String? password,
    required String? confirm,
  }) {
    final confirmValue = confirm ?? '';
    if (confirmValue.isEmpty) {
      return const ValidationResult.invalid('비밀번호 확인을 입력해 주세요.');
    }
    if (password != confirmValue) {
      return const ValidationResult.invalid('비밀번호가 일치하지 않습니다.');
    }
    return const ValidationResult.valid();
  }
}
