import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/core/session/auth_session.dart';

/// PUSH·거점 한도 — 지갑 + 기본 플랜 기준
abstract final class PushPlanEnforcement {
  static PremiumPartnershipTier get activePlan =>
      PartnershipPlanDefaults.activePlan;

  static PushRadiusTier get maxRadiusTier => defaultRadiusTier;

  static int get freePushRadiusM => PushPackageCatalog.freePushRadiusM;
  static int get packagePushRadiusM => PushPackageCatalog.packagePushRadiusM;
  static int get packageUnitPriceKrw => PushPackageCatalog.singlePackagePriceKrw;

  static PushRadiusTier get defaultRadiusTier => PushRadiusTier.standard1km;

  static PushRadiusTier get packageRadiusTier => PushRadiusTier.standard1km;

  static DesignatedPointTier get maxPointTier => DesignatedPointTier.onePoint;

  static int get extraPushPriceKrw => packageUnitPriceKrw;

  static Future<int> maxLocationSlots() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return PushPackageCatalog.baseLocationSlots;
    return PushWalletService().maxLocationSlots(profile);
  }

  static int get maxBasePointsSync {
    final wallet =
        AuthSession.instance.currentUser?.corporateProfile?.pushWallet;
    return PushWalletCreditPolicy.effectiveMaxExposurePoints(
      wallet: wallet ?? const EmployerPushWallet(),
      currentPointsLength: 1,
    );
  }

  static List<PushRadiusTier> get allowedRadiusTiers => [
        PushRadiusTier.standardFree1km,
        PushRadiusTier.standard1km,
      ];

  static List<int> get allowedSliderKmSteps => [1];

  static bool isRadiusAllowed(PushRadiusTier tier) =>
      tier == PushRadiusTier.standardFree1km ||
      tier == PushRadiusTier.standard1km ||
      tier == PushRadiusTier.radius0km;

  static PushRadiusTier clampRadius(PushRadiusTier tier) {
    if (isRadiusAllowed(tier)) return tier;
    return defaultRadiusTier;
  }

  static bool isPointTierAllowed(DesignatedPointTier tier) =>
      tier.maxPoints <= maxBasePointsSync;

  static DesignatedPointTier clampPointTier(DesignatedPointTier tier) {
    if (isPointTierAllowed(tier)) return tier;
    return DesignatedPointTier.onePoint;
  }

  static List<DesignatedPointTier> get allowedPointTiers {
    final max = maxBasePointsSync;
    return DesignatedPointOptions.selectableTiers
        .where((t) => t.maxPoints <= max)
        .toList();
  }

  static String planLimitSummary() =>
      '근무지 주변 ${PushPackageCatalog.pushRadiusLabel} 무료 · 일자리 알림핀은 설정 시 이용';

  static String pushCountSummary({required int usedToday}) {
    final wallet =
        AuthSession.instance.currentUser?.corporateProfile?.pushWallet;
    final credits = wallet?.packageCredits ?? 0;
    return '일자리 알림핀 $credits회 · '
        '${PushPackageCatalog.krwSuffix(packageUnitPriceKrw)}부터 구매';
  }
}
