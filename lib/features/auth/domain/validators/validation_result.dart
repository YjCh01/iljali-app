/// 입력값 검증 결과
class ValidationResult {
  const ValidationResult._({required this.isValid, this.message});

  const ValidationResult.valid() : this._(isValid: true);

  const ValidationResult.invalid(String message)
      : this._(isValid: false, message: message);

  final bool isValid;
  final String? message;
}
