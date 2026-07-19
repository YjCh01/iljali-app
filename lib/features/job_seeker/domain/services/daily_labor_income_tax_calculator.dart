/// 일용근로소득세 — 소득세법 시행령 기준 정확한 산식(조견표 불필요).
///
/// 세액 = max(0, 일급여액 - 150,000원) × 6% × (1 - 55%) = 초과분 × 2.7%
/// 정수 연산만 사용해 부동소수점 반올림 오차(예: 0.06×0.45 ≠ 0.027)를 피한다.
abstract final class DailyLaborIncomeTaxCalculator {
  static const dailyDeduction = 150000;

  static int incomeTax(int dailyGrossPay) {
    final taxable = dailyGrossPay - dailyDeduction;
    if (taxable <= 0) return 0;
    return (taxable * 27) ~/ 1000;
  }

  static int localIncomeTax(int incomeTax) => (incomeTax * 10) ~/ 100;
}
