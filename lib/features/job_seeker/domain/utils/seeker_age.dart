/// 구직자 만나이(국제 나이) 계산
abstract final class SeekerAge {
  /// 생일이 지났는지 기준으로 만나이 계산
  static int? internationalAge(
    DateTime? birthDate, {
    DateTime? reference,
  }) {
    if (birthDate == null) return null;
    final today = reference ?? DateTime.now();
    var age = today.year - birthDate.year;
    final birthdayPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) age--;
    return age < 0 ? null : age;
  }

  static String formatLabel(DateTime? birthDate, {DateTime? reference}) {
    final age = internationalAge(birthDate, reference: reference);
    if (age == null) return '-';
    return '만 $age세';
  }
}
