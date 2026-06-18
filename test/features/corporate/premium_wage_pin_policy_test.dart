import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/constants/labor_constants.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/utils/premium_wage_pin_policy.dart';

void main() {
  group('PremiumWagePinPolicy', () {
    const eightHourSchedule = '09:00~18:00';

    test('hourly at premium threshold qualifies', () {
      expect(
        PremiumWagePinPolicy.qualifies(
          payType: SalaryPayType.hourly,
          wageFieldText: '${LaborConstants.premiumHourlyThreshold}',
          workSchedule: eightHourSchedule,
        ),
        isTrue,
      );
    });

    test('daily 150000 with 8h schedule qualifies', () {
      final threshold =
          PremiumWagePinPolicy.dailyThresholdForSchedule(eightHourSchedule);
      expect(threshold, 90560);
      expect(
        PremiumWagePinPolicy.qualifies(
          payType: SalaryPayType.daily,
          wageFieldText: '150000',
          workSchedule: eightHourSchedule,
        ),
        isTrue,
      );
    });

    test('daily below threshold does not qualify', () {
      expect(
        PremiumWagePinPolicy.qualifies(
          payType: SalaryPayType.daily,
          wageFieldText: '80000',
          workSchedule: eightHourSchedule,
        ),
        isFalse,
      );
    });

    test('qualifiesFromWageLabel for stored daily wage label', () {
      expect(
        PremiumWagePinPolicy.qualifiesFromWageLabel(
          wageLabel: '일급 150,000원',
          workSchedule: eightHourSchedule,
        ),
        isTrue,
      );
    });
  });
}
