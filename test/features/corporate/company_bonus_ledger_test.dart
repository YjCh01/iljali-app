import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/data/repositories/company_bonus_ledger_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signup bonus granted only once per company key', () async {
    final repo = await CompanyBonusLedgerRepository.create();
    const key = '1234567890';

    expect(await repo.tryClaimSignupBonus(key), isTrue);
    expect(await repo.tryClaimSignupBonus(key), isFalse);
    expect(await repo.isSignupBonusClaimed(key), isTrue);
  });

  test('different company keys get separate bonus claims', () async {
    final repo = await CompanyBonusLedgerRepository.create();

    expect(await repo.tryClaimSignupBonus('1111111111'), isTrue);
    expect(await repo.tryClaimSignupBonus('2222222222'), isTrue);
    expect(await repo.isSignupBonusClaimed('1111111111'), isTrue);
    expect(await repo.isSignupBonusClaimed('2222222222'), isTrue);
  });

  test('verification bonus granted only once per company key', () async {
    final repo = await CompanyBonusLedgerRepository.create();
    const key = '9898989898';

    expect(await repo.tryClaimVerificationBonus(key), isTrue);
    expect(await repo.tryClaimVerificationBonus(key), isFalse);
    expect(await repo.isVerificationBonusClaimed(key), isTrue);
  });
}
