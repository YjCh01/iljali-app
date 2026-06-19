import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';

void main() {
  group('PushCreditVisualTheme', () {
    test('fromWallet uses basic grey when no package credits', () {
      const wallet = EmployerPushWallet(signupBonusRemaining: 5);
      final theme = PushCreditVisualTheme.fromWallet(wallet);
      expect(theme.tier, PushCreditVisualTier.basic);
    });

    test('fromWallet uses package purple when package credits exist', () {
      const wallet = EmployerPushWallet(packageCredits: 10);
      final theme = PushCreditVisualTheme.fromWallet(wallet);
      expect(theme.tier, PushCreditVisualTier.package);
    });

    test('fromWallet uses package for 100 pack buyer with credits', () {
      const wallet = EmployerPushWallet(
        packageCredits: 50,
        purchased100PackBundle: true,
      );
      final theme = PushCreditVisualTheme.fromWallet(wallet);
      expect(theme.tier, PushCreditVisualTier.package);
    });

    test('fromNextPushConsume uses package when credits available', () {
      const wallet = EmployerPushWallet(
        signupBonusRemaining: 5,
        packageCredits: 10,
      );
      final theme = PushCreditVisualTheme.fromNextPushConsume(wallet);
      expect(theme.tier, PushCreditVisualTier.package);
    });

    test('fromNextPushConsume uses basic when no credits', () {
      const wallet = EmployerPushWallet(signupBonusRemaining: 0);
      final theme = PushCreditVisualTheme.fromNextPushConsume(wallet);
      expect(theme.tier, PushCreditVisualTier.basic);
    });
  });
}
