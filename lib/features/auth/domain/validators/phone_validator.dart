import 'package:map/features/auth/domain/validators/validation_result.dart';

/// 휴대폰 번호 검증 (숫자 11자리)
abstract final class PhoneValidator {
  static final RegExp _digitsOnly = RegExp(r'^\d{11}$');

  static ValidationResult validate(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return const ValidationResult.invalid('휴대폰 번호를 입력해 주세요.');
    }
    if (phone.contains('-')) {
      return const ValidationResult.invalid('하이픈(-) 없이 숫자만 입력해 주세요.');
    }
    if (!_digitsOnly.hasMatch(phone)) {
      return const ValidationResult.invalid('휴대폰 번호는 숫자 11자리여야 합니다.');
    }
    return const ValidationResult.valid();
  }
}
