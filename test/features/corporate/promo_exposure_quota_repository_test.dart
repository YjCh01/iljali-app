import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:map/features/corporate/data/repositories/promo_exposure_quota_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FreeExposureLaunchPolicy.resetCache();
  });

  test('tryConsume enforces monthly cap per company', () async {
    final repo = await PromoExposureQuotaRepository.create();
    const company = 'corp-alpha';

    expect(
      await repo.tryConsume(company, FreeExposureLaunchPolicy.monthlyActivationCapPerCompany),
      isTrue,
    );
    expect(
      await repo.tryConsume(company, 1),
      isFalse,
    );
    expect(await repo.usedThisMonth(company), FreeExposureLaunchPolicy.monthlyActivationCapPerCompany);
  });

  test('quota resets next calendar month', () async {
    final repo = await PromoExposureQuotaRepository.create();
    const company = 'corp-beta';
    final june = DateTime(2026, 6, 15);

    expect(await repo.tryConsume(company, 10, june), isTrue);
    expect(await repo.tryConsume(company, 1, june), isFalse);

    final july = DateTime(2026, 7, 1);
    expect(await repo.tryConsume(company, 1, july), isTrue);
    expect(await repo.usedThisMonth(company, july), 1);
  });
}
