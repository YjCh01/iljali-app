import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/core/session/auth_session.dart';

/// 푸시·거점 한도 — 지갑 + 기본 플랜 기준
abstract final class PushPlanEnforcement {
  static PremiumPartnershipTier get activePlan =>
      PartnershipPlanDefaults.activePlan;

  static PushRadiusTier get maxRadiusTier => defaultFreeRadiusTier;

  static int get freePushRadiusM => PushPackageCatalog.freePushRadiusM;
  static int get packagePushRadiusM => PushPackageCatalog.packagePushRadiusM;
  static int get dailyFreePushLimit => PushPackageCatalog.dailyFreePush;
  static int get packageUnitPriceKrw => PushPackageCatalog.singlePackagePriceKrw;

  static PushRadiusTier get defaultFreeRadiusTier =>
      PushRadiusTier.standardFree1km;

  static PushRadiusTier get packageRadiusTier => PushRadiusTier.standard1km;

  static DesignatedPointTier get maxPointTier => DesignatedPointTier.onePoint;

  static int get dailyPushLimit => dailyFreePushLimit;

  static int get extraPushPriceKrw => packageUnitPriceKrw;

  static Future<int> maxLocationSlots() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return PushPackageCatalog.baseLocationSlots;
    return PushWalletService().maxLocationSlots(profile);
  }

  static int get maxBasePointsSync {
    final wallet = AuthSession.instance.currentUser?.corporateProfile?.pushWallet;
    return wallet?.totalLocationSlots ?? PushPackageCatalog.baseLocationSlots;
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
    return defaultFreeRadiusTier;
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
      '${PushPackageCatalog.defaultPlanLabel} · '
      '반경 ${PushPackageCatalog.pushRadiusLabel} · '
      '일 ${PushPackageCatalog.dailyFreePush}회 · '
      '패키지 ${PushPackageCatalog.krwSuffix(packageUnitPriceKrw)}';

  static String pushCountSummary({required int usedToday}) {
    final wallet =
        AuthSession.instance.currentUser?.corporateProfile?.pushWallet;
    final limit = dailyPushLimit;
    final remaining = (limit - usedToday).clamp(0, limit);
    final credits = wallet?.packageCredits ?? 0;
    if (remaining > 0) {
      return '오늘 무료 $usedToday/$limit · 패키지 $credits회 · '
          '초과 시 패키지 구매';
    }
    return '오늘 무료 소진 · 패키지 $credits회 · '
        '${PushPackageCatalog.krwSuffix(packageUnitPriceKrw)}부터 구매';
  }
}
