/// 사업자등록번호(10자리) — 형식·체크섬 검증
class BusinessRegistrationNumber {
  const BusinessRegistrationNumber._(this.digits);

  final String digits;

  static BusinessRegistrationNumber? tryParse(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.length != 10) return null;
    if (!isValidChecksum(normalized)) return null;
    return BusinessRegistrationNumber._(normalized);
  }

  static String? formatErrorMessage(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      return '사업자등록번호를 입력해 주세요.';
    }
    if (normalized.length != 10) {
      return '사업자등록번호 10자리를 입력해 주세요.';
    }
    if (!isValidChecksum(normalized)) {
      return '유효하지 않은 사업자등록번호입니다. 번호를 다시 확인해 주세요.';
    }
    return null;
  }

  /// 국세청 사업자등록번호 검증번호(체크디짓) 알고리즘
  static bool isValidChecksum(String digits) {
    if (digits.length != 10 || !RegExp(r'^\d{10}$').hasMatch(digits)) {
      return false;
    }
    const weights = [1, 3, 7, 1, 3, 7, 1, 3, 5];
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    sum += (int.parse(digits[8]) * 5) ~/ 10;
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(digits[9]);
  }

  @override
  String toString() => digits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessRegistrationNumber && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
