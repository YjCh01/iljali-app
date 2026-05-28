import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

/// 거점(지점) 한도 — 패키지 지갑 기준
abstract final class BranchPlanLimits {
  static Future<int> maxBranchesForCurrentUser() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return PushPackageCatalog.baseLocationSlots;
    final wallet = await PushWalletService().loadWallet(profile);
    return wallet.totalLocationSlots;
  }

  static int maxBranches(PremiumPartnershipTier tier) => maxBranchesSync(tier);

  static int maxBranchesSync(PremiumPartnershipTier tier) {
    final wallet =
        AuthSession.instance.currentUser?.corporateProfile?.pushWallet;
    return wallet?.totalLocationSlots ?? PushPackageCatalog.baseLocationSlots;
  }

  static String limitLabel(PremiumPartnershipTier tier) {
    final n = maxBranchesSync(tier);
    return '$n곳';
  }
}
