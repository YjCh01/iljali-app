/// 4대보험료(근로자 부담분) — 월급(상용직) 근로자 기준 요율.
/// 정수 연산만 사용해 부동소수점 반올림 오차를 피한다.
abstract final class FourMajorInsuranceCalculator {
  static const nationalPensionRate = 0.045;
  static const healthInsuranceRate = 0.03545;
  static const longTermCareRateOfHealthInsurance = 0.1295;
  static const employmentInsuranceRate = 0.009;

  static int nationalPension(int monthlyGrossPay) =>
      (monthlyGrossPay * 45) ~/ 1000;

  static int healthInsurance(int monthlyGrossPay) =>
      (monthlyGrossPay * 3545) ~/ 100000;

  static int longTermCareInsurance(int healthInsuranceAmount) =>
      (healthInsuranceAmount * 1295) ~/ 10000;

  static int employmentInsurance(int monthlyGrossPay) =>
      (monthlyGrossPay * 9) ~/ 1000;
}
