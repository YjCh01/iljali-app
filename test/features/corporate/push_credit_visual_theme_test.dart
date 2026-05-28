import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';

void main() {
  group('PushCreditVisualTheme', () {
    test('fromWallet uses basic grey when only signup bonus', () {
      const wallet = EmployerPushWallet(signupBonusRemaining: 5);
      final theme = PushCreditVisualTheme.fromWallet(wallet);
      expect(theme.tier, PushCreditVisualTier.basic);
      expect(theme.showBasicPassNotice, isTrue);
    });

    test('fromWallet uses package purple when package credits exist', () {
      const wallet = EmployerPushWallet(packageCredits: 10);
      final theme = PushCreditVisualTheme.fromWallet(wallet);
      expect(theme.tier, PushCreditVisualTier.package);
      expect(theme.showBasicPassNotice, isFalse);
    });

    test('fromWallet uses gold for 100 pack buyer', () {
      const wallet = EmployerPushWallet(
        packageCredits: 50,
        purchased100PackBundle: true,
      );
      final theme = PushCreditVisualTheme.fromWallet(wallet);
      expect(theme.tier, PushCreditVisualTier.premium100);
    });

    test('fromNextPushConsume uses basic when daily free available', () {
      const wallet = EmployerPushWallet(
        signupBonusRemaining: 5,
        packageCredits: 10,
      );
      final theme = PushCreditVisualTheme.fromNextPushConsume(wallet);
      expect(theme.tier, PushCreditVisualTier.basic);
    });

    test('fromNextPushConsume uses package when only package credits left', () {
      final today = DateTime.now();
      final dayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final wallet = EmployerPushWallet(
        signupBonusRemaining: 0,
        packageCredits: 3,
        lastFreePushDayKey: dayKey,
      );
      final theme = PushCreditVisualTheme.fromNextPushConsume(wallet);
      expect(theme.tier, PushCreditVisualTier.package);
    });
  });
}
