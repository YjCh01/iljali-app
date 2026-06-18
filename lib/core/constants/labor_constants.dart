/// 2026년 적용 최저임금 (고용노동부 고시, 시간당)
abstract final class LaborConstants {
  static const int minimumHourlyWage2026 = 10320;

  /// 시급이 이 금액 이상이면 지도 핀 하늘색(premiumWage) 등급
  static const int premiumHourlyThreshold = minimumHourlyWage2026 + 1000;

  static String get premiumWageMapHint =>
      '급여가 최저임금(시급 ${formatWonAmount(minimumHourlyWage2026)})보다 '
      '시간당 1,000원 이상 높게 책정되면 지도에서 하늘색 핀으로 강조 표시됩니다.';

  static const String defaultHourlyWageText = '10320';

  /// 시급 입력란 기본 표시 — 예: 10,320
  static String get defaultHourlyWageFieldText =>
      formatAmountNumber(minimumHourlyWage2026);

  static String formatAmountNumber(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  static String formatWonAmount(int amount) {
    return '${formatAmountNumber(amount)}원';
  }

  static int? parseWageFieldAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  /// 저장값(숫자·레이블) → 입력란 표시 (쉼표 숫자만)
  static String initialHourlyWageFieldText([String? raw]) {
    final amount = parseWageFieldAmount(raw ?? '') ?? minimumHourlyWage2026;
    return formatAmountNumber(amount);
  }

  /// 표준 근무(09:00~18:00, 휴게 1시간) 기준 1일 유급 근무시간
  static const double standardDailyPaidHours = 8.0;
}
