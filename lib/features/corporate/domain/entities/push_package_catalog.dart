import 'package:map/features/corporate/domain/entities/recruitment_product_kind.dart';

/// 일자리·정류장 표시핀·PUSH 이용권 요금 카탈로그
abstract final class PushPackageCatalog {
  static const jobPinProductName = '일자리 알림핀';
  static const shuttlePinProductName = '정류장 표시핀';
  static const comboProductName = 'PUSH 알림권';
  static const pushOnlyShopProductName = 'PUSH 이용권';

  /// @deprecated — [pushOnlyShopProductName] 상점 표기, 지갑·발송은 PUSH 알림권 유지
  static const pushTicketProductName = 'PUSH 알림권';

  /// @deprecated — [jobPinProductName]
  static const productName = jobPinProductName;

  // ── 공고 등록 (무료) ──
  static const defaultPlanLabel = '기본 플랜';
  static const freePushRadiusM = 700;
  static const packagePushRadiusM = 700;
  static const signupBonusPushes = 2;
  static const verificationBonusPushes = 5;
  static const signupBonusValidDays = 90;
  static const baseLocationSlots = 1;

  /// 공고 적용 시점 D+0 → 노출 종료 D+1 23:59:59
  static const exposureEndsLabel = '적용 후 D+1 23:59:59까지';

  static const pack10Count = 10;
  static const pack10DiscountPercent = 10;
  static const pack10Suffix = 'pack_10';

  // ── 단가 ──
  static const exposureUnitPriceKrw = 19900;
  static const exposureWithPushUnitPriceKrw = 35900;
  static const pushOnlyUnitPriceKrw = 19900;

  /// @deprecated — [exposureUnitPriceKrw]와 동일
  static const singlePackagePriceKrw = exposureUnitPriceKrw;

  static const jobPinSingleId = 'job_pin_single';
  static const jobPinPack10Id = 'job_pin_pack_10';
  static const shuttlePinSingleId = 'shuttle_pin_single';
  static const shuttlePinPack10Id = 'shuttle_pin_pack_10';

  /// @deprecated — [jobPinSingleId]
  static const exposureSingleId = jobPinSingleId;

  /// @deprecated — [jobPinPack10Id]
  static const exposurePack10Id = jobPinPack10Id;

  static const comboSingleId = 'combo_single';
  static const comboPack10Id = 'combo_pack_10';
  static const pushSingleId = 'push_single';
  static const pushPack10Id = 'push_pack_10';

  /// @deprecated — [jobPinSingleId]
  static const singlePackageId = jobPinSingleId;

  /// @deprecated — [jobPinPack10Id]
  static const pack10Id = jobPinPack10Id;

  static const jobPinDescription =
      '일자리 알림핀을 지도 상의 번화가, 인구 밀집지역 등에 추가하여 모집 효과를 높일 수 있습니다.';
  static const shuttlePinDescription =
      '운영 중인 통근버스의 정류장과 노선도를 지도 상에 직접 표시하고 연결하여 모집 효과를 높일 수 있습니다.';
  static const comboDescription =
      '핀 설치와 PUSH, 모두 한 번에 · 반경 700m · $exposureEndsLabel';
  static const pushOnlyDescription =
      '일자리 알림핀·정류장 표시핀을 노출한 지역 700m 반경 이용자에게 모집 공고 PUSH를 보낼 수 있습니다.';

  /// @deprecated — [jobPinDescription]
  static const exposureDescription = jobPinDescription;

  /// @deprecated — [comboDescription]
  static const exposureWithPushDescription = comboDescription;

  static const singlePackageLabel = jobPinProductName;

  static const packageCreditValidDays = 365;
  static const shuttleOverlayAddonId = 'shuttle_route_overlay';

  static int pack10Price(int unitPriceKrw) =>
      unitPriceKrw * pack10Count * (100 - pack10DiscountPercent) ~/ 100;

  static const bundles = [
    PushPackageBundleOffer(
      id: jobPinPack10Id,
      kind: RecruitmentProductKind.exposureOnly,
      exposureVariant: ExposureShopVariant.jobPin,
      label: '10회 팩',
      packageCount: pack10Count,
      priceKrw: exposureUnitPriceKrw *
          pack10Count *
          (100 - pack10DiscountPercent) ~/
          100,
      discountPercent: pack10DiscountPercent,
      marketingLine: '',
    ),
    PushPackageBundleOffer(
      id: shuttlePinPack10Id,
      kind: RecruitmentProductKind.exposureOnly,
      exposureVariant: ExposureShopVariant.shuttlePin,
      label: '10회 팩',
      packageCount: pack10Count,
      priceKrw: exposureUnitPriceKrw *
          pack10Count *
          (100 - pack10DiscountPercent) ~/
          100,
      discountPercent: pack10DiscountPercent,
      marketingLine: '',
    ),
    PushPackageBundleOffer(
      id: pushPack10Id,
      kind: RecruitmentProductKind.pushOnly,
      label: '10회 팩',
      packageCount: pack10Count,
      priceKrw: pushOnlyUnitPriceKrw *
          pack10Count *
          (100 - pack10DiscountPercent) ~/
          100,
      discountPercent: pack10DiscountPercent,
      marketingLine: '',
    ),
  ];

  static const allOffers = [
    PushPackageBundleOffer(
      id: jobPinSingleId,
      kind: RecruitmentProductKind.exposureOnly,
      exposureVariant: ExposureShopVariant.jobPin,
      label: jobPinProductName,
      packageCount: 1,
      priceKrw: exposureUnitPriceKrw,
      discountPercent: 0,
      marketingLine: jobPinDescription,
    ),
    PushPackageBundleOffer(
      id: jobPinPack10Id,
      kind: RecruitmentProductKind.exposureOnly,
      exposureVariant: ExposureShopVariant.jobPin,
      label: '10회 팩',
      packageCount: pack10Count,
      priceKrw: exposureUnitPriceKrw *
          pack10Count *
          (100 - pack10DiscountPercent) ~/
          100,
      discountPercent: pack10DiscountPercent,
      marketingLine: '',
    ),
    PushPackageBundleOffer(
      id: shuttlePinSingleId,
      kind: RecruitmentProductKind.exposureOnly,
      exposureVariant: ExposureShopVariant.shuttlePin,
      label: shuttlePinProductName,
      packageCount: 1,
      priceKrw: exposureUnitPriceKrw,
      discountPercent: 0,
      marketingLine: shuttlePinDescription,
    ),
    PushPackageBundleOffer(
      id: shuttlePinPack10Id,
      kind: RecruitmentProductKind.exposureOnly,
      exposureVariant: ExposureShopVariant.shuttlePin,
      label: '10회 팩',
      packageCount: pack10Count,
      priceKrw: exposureUnitPriceKrw *
          pack10Count *
          (100 - pack10DiscountPercent) ~/
          100,
      discountPercent: pack10DiscountPercent,
      marketingLine: '',
    ),
    PushPackageBundleOffer(
      id: pushSingleId,
      kind: RecruitmentProductKind.pushOnly,
      label: pushOnlyShopProductName,
      packageCount: 1,
      priceKrw: pushOnlyUnitPriceKrw,
      discountPercent: 0,
      marketingLine: pushOnlyDescription,
    ),
    PushPackageBundleOffer(
      id: pushPack10Id,
      kind: RecruitmentProductKind.pushOnly,
      label: '10회 팩',
      packageCount: pack10Count,
      priceKrw: pushOnlyUnitPriceKrw *
          pack10Count *
          (100 - pack10DiscountPercent) ~/
          100,
      discountPercent: pack10DiscountPercent,
      marketingLine: '',
    ),
  ];

  static const shopSections = [
    PushPackageShopSection(
      title: jobPinProductName,
      subtitle: jobPinDescription,
      offerIds: [jobPinSingleId, jobPinPack10Id],
    ),
    PushPackageShopSection(
      title: shuttlePinProductName,
      subtitle: shuttlePinDescription,
      offerIds: [shuttlePinSingleId, shuttlePinPack10Id],
    ),
    PushPackageShopSection(
      title: pushOnlyShopProductName,
      subtitle: pushOnlyDescription,
      offerIds: [pushSingleId, pushPack10Id],
    ),
  ];

  static List<PushPackageBundleOffer> offersForKind(
    RecruitmentProductKind kind, {
    ExposureShopVariant? variant,
  }) {
    return allOffers
        .where(
          (o) =>
              o.kind == kind &&
              (variant == null || o.exposureVariant == variant),
        )
        .toList(growable: false);
  }

  static List<PushPackageBundleOffer> get exposureOffers =>
      offersForKind(RecruitmentProductKind.exposureOnly);

  static List<PushPackageBundleOffer> get jobPinOffers =>
      offersForKind(
        RecruitmentProductKind.exposureOnly,
        variant: ExposureShopVariant.jobPin,
      );

  static List<PushPackageBundleOffer> get shuttlePinOffers =>
      offersForKind(
        RecruitmentProductKind.exposureOnly,
        variant: ExposureShopVariant.shuttlePin,
      );

  static List<PushPackageBundleOffer> get exposureWithPushOffers =>
      offersForKind(RecruitmentProductKind.exposureWithPush);

  static List<PushPackageBundleOffer> get pushOnlyOffers =>
      offersForKind(RecruitmentProductKind.pushOnly);

  static List<PushPackageBundleOffer> resolveShopSectionOffers(
    PushPackageShopSection section,
  ) {
    return section.offerIds
        .map((id) => findById(id))
        .whereType<PushPackageBundleOffer>()
        .toList(growable: false);
  }

  static bool supportsQuantitySelector(String offerId) {
    for (final o in allOffers) {
      if (o.id == offerId) return o.supportsQuantitySelector;
    }
    return offerId == 'single' || offerId == 'pack_10';
  }

  static PushPackageBundleOffer? findById(String id) {
    final normalized = switch (id) {
      'single' || 'exposure_single' => jobPinSingleId,
      'pack_10' || 'exposure_pack_10' => jobPinPack10Id,
      _ => id,
    };
    for (final o in allOffers) {
      if (o.id == normalized) return o;
    }
    return null;
  }

  static String formatKrw(int amount) => amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  static const pushRadiusLabel = '700m';

  static const detailSeparator = ' · ';

  static String bundleCardDetailLine({
    required int priceKrw,
    required int packageCount,
    required RecruitmentProductKind kind,
    ExposureShopVariant? exposureVariant,
  }) {
    final unit = kind.unitLabel;
    final prefix = exposureVariant?.productName;
    final detail = '${formatKrw(priceKrw)}원$detailSeparator반경 $pushRadiusLabel'
        '$detailSeparator$packageCount$unit';
    if (prefix == null) return detail;
    return '$prefix$detailSeparator$detail';
  }

  static String krwSuffix(int amount) => '${formatKrw(amount)}원';
}

class PushPackageShopSection {
  const PushPackageShopSection({
    required this.title,
    required this.subtitle,
    required this.offerIds,
  });

  final String title;
  final String subtitle;
  final List<String> offerIds;
}

class PushPackageBundleOffer {
  const PushPackageBundleOffer({
    required this.id,
    required this.kind,
    required this.label,
    required this.packageCount,
    required this.priceKrw,
    required this.discountPercent,
    required this.marketingLine,
    this.exposureVariant,
    this.extraBenefitLines = const [],
  });

  final String id;
  final RecruitmentProductKind kind;
  final ExposureShopVariant? exposureVariant;
  final String label;
  final int packageCount;
  final int priceKrw;
  final int discountPercent;
  final String marketingLine;
  final List<String> extraBenefitLines;

  int get unitPriceKrw => (priceKrw / packageCount).round();

  String get cardDetailLine => PushPackageCatalog.bundleCardDetailLine(
        priceKrw: priceKrw,
        packageCount: packageCount,
        kind: kind,
        exposureVariant: exposureVariant,
      );

  String get priceLabel => PushPackageCatalog.krwSuffix(priceKrw);

  String get productName => switch (kind) {
        RecruitmentProductKind.exposureOnly => switch (exposureVariant) {
            ExposureShopVariant.jobPin => PushPackageCatalog.jobPinProductName,
            ExposureShopVariant.shuttlePin =>
              PushPackageCatalog.shuttlePinProductName,
            null => PushPackageCatalog.jobPinProductName,
          },
        RecruitmentProductKind.exposureWithPush => packageCount == 1
            ? PushPackageCatalog.comboProductName
            : '${PushPackageCatalog.comboProductName} $label',
        RecruitmentProductKind.pushOnly => packageCount == 1
            ? PushPackageCatalog.pushOnlyShopProductName
            : '${PushPackageCatalog.pushOnlyShopProductName} $label',
      };

  bool get supportsQuantitySelector => true;
}
