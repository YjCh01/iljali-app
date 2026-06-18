import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

/// [PushWalletService.loadWalletDetailed] 결과 — 보너스 지급 여부 포함.
class PushWalletLoadOutcome {
  const PushWalletLoadOutcome({
    required this.wallet,
    this.grantedSignupBonus = false,
    this.grantedVerificationBonus = false,
  });

  final EmployerPushWallet wallet;
  final bool grantedSignupBonus;
  final bool grantedVerificationBonus;

  bool get grantedAnyBonus =>
      grantedSignupBonus || grantedVerificationBonus;
}
