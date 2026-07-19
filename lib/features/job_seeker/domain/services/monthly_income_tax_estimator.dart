/// 월급(상용직) 소득세 추정 — 국세청 근로소득 간이세액표는 방대한 조견표라
/// 그대로 담을 수 없어, 그 표를 만드는 근거인 연말정산 산출 방식(연간 환산 →
/// 근로소득공제 → 인적공제 → 종합소득세율 → 근로소득세액공제 → 12분의 1)을
/// 그대로 적용한 근사치다. 다자녀 추가공제 등 세부 조정은 생략되어 실제 원천징수
/// 세액과 차이가 있을 수 있다. 정수 연산만 사용해 부동소수점 반올림 오차를 피한다.
abstract final class MonthlyIncomeTaxEstimator {
  static const _personalDeductionPerPerson = 1500000;

  static int estimateMonthlyIncomeTax({
    required int monthlyGrossPay,
    required int dependents,
  }) {
    final annualGross = monthlyGrossPay * 12;
    final earnedIncomeDeduction = _earnedIncomeDeduction(annualGross);
    final earnedIncomeAmount =
        (annualGross - earnedIncomeDeduction).clamp(0, annualGross).toInt();

    final personalDeduction =
        _personalDeductionPerPerson * dependents.clamp(1, 20);
    final taxBase = (earnedIncomeAmount - personalDeduction)
        .clamp(0, earnedIncomeAmount)
        .toInt();

    final calculatedTax = _progressiveIncomeTax(taxBase);
    final taxCredit = _earnedIncomeTaxCredit(
      calculatedTax: calculatedTax,
      annualGross: annualGross,
    );
    final finalAnnualTax = (calculatedTax - taxCredit).clamp(0, calculatedTax);

    return finalAnnualTax ~/ 12;
  }

  static int localIncomeTax(int incomeTax) => (incomeTax * 10) ~/ 100;

  /// 근로소득공제 — 소득세법 제47조.
  static int _earnedIncomeDeduction(int annualGross) {
    if (annualGross <= 5000000) {
      return (annualGross * 7) ~/ 10;
    }
    if (annualGross <= 15000000) {
      return 3500000 + ((annualGross - 5000000) * 4) ~/ 10;
    }
    if (annualGross <= 45000000) {
      return 7500000 + ((annualGross - 15000000) * 15) ~/ 100;
    }
    if (annualGross <= 100000000) {
      return 12000000 + ((annualGross - 45000000) * 5) ~/ 100;
    }
    return 14750000 + ((annualGross - 100000000) * 2) ~/ 100;
  }

  /// 종합소득세 기본세율(누진세율) — 소득세법 제55조.
  static int _progressiveIncomeTax(int taxBase) {
    if (taxBase <= 14000000) {
      return (taxBase * 6) ~/ 100;
    }
    if (taxBase <= 50000000) {
      return 840000 + ((taxBase - 14000000) * 15) ~/ 100;
    }
    if (taxBase <= 88000000) {
      return 6240000 + ((taxBase - 50000000) * 24) ~/ 100;
    }
    if (taxBase <= 150000000) {
      return 15360000 + ((taxBase - 88000000) * 35) ~/ 100;
    }
    if (taxBase <= 300000000) {
      return 37060000 + ((taxBase - 150000000) * 38) ~/ 100;
    }
    if (taxBase <= 500000000) {
      return 94060000 + ((taxBase - 300000000) * 40) ~/ 100;
    }
    if (taxBase <= 1000000000) {
      return 174060000 + ((taxBase - 500000000) * 42) ~/ 100;
    }
    return 384060000 + ((taxBase - 1000000000) * 45) ~/ 100;
  }

  /// 근로소득세액공제 — 소득세법 제59조(한도 포함).
  static int _earnedIncomeTaxCredit({
    required int calculatedTax,
    required int annualGross,
  }) {
    final credit = calculatedTax <= 1300000
        ? (calculatedTax * 55) ~/ 100
        : 715000 + ((calculatedTax - 1300000) * 30) ~/ 100;

    final int limit;
    if (annualGross <= 33000000) {
      limit = 740000;
    } else if (annualGross <= 70000000) {
      final reduced = 740000 - ((annualGross - 33000000) ~/ 1000 * 8);
      limit = reduced.clamp(660000, 740000);
    } else if (annualGross <= 120000000) {
      final reduced = 660000 - ((annualGross - 70000000) ~/ 1000 * 1);
      limit = reduced.clamp(500000, 660000);
    } else {
      final reduced = 500000 - ((annualGross - 120000000) ~/ 1000 * 1);
      limit = reduced.clamp(200000, 500000);
    }

    return credit.clamp(0, limit);
  }
}
