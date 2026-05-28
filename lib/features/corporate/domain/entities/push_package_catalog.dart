/// 푸시·거점 패키지 요금 카탈로그 (2026 — 추가구매 우선)
abstract final class PushPackageCatalog {
  // ── 기본 플랜 (무료) ──
  static const defaultPlanLabel = '기본 플랜';
  static const freePushRadiusM = 1000;
  static const packagePushRadiusM = 1000;
  static const dailyFreePush = 1;
  static const signupBonusPushes = 5;
  static const signupBonusValidDays = 90;
  static const baseLocationSlots = 1;

  // ── 단품 ──
  static const singlePackagePriceKrw = 5000;
  static const singlePackageId = 'single';
  static const singlePackageLabel = '공고 노출·모집 패키지';
  static const singlePackageDescription =
      '노출 지역 및 범위를 지정하고 공고 알림을 보냅니다.';

  static const packageCreditValidDays = 365;

  static const bundles = [
    PushPackageBundleOffer(
      id: 'pack_10',
      label: '10회 팩',
      packageCount: 10,
      priceKrw: 45000,
      discountPercent: 10,
      marketingLine: '10% 할인',
    ),
    PushPackageBundleOffer(
      id: 'pack_30',
      label: '30회 팩',
      packageCount: 30,
      priceKrw: 120000,
      discountPercent: 20,
      marketingLine: '20% 할인',
    ),
    PushPackageBundleOffer(
      id: 'pack_100',
      label: '100회 팩',
      packageCount: 100,
      priceKrw: 350000,
      discountPercent: 30,
      marketingLine: '30% 할인',
      extraBenefitLines: [
        '지도 프리미엄 핀(◆) — 모든 채용 공고에 골드 핀으로 눈에 띄게 노출',
        '지도를 축소해도 일반 공고와 색·크기가 확실히 구분됩니다',
      ],
    ),
  ];

  static const allOffers = [
    PushPackageBundleOffer(
      id: singlePackageId,
      label: singlePackageLabel,
      packageCount: 1,
      priceKrw: singlePackagePriceKrw,
      discountPercent: 0,
      marketingLine: singlePackageDescription,
    ),
    ...bundles,
  ];

  static PushPackageBundleOffer? findById(String id) {
    for (final o in allOffers) {
      if (o.id == id) return o;
    }
    return null;
  }

  static String formatKrw(int amount) => amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  static String get pushRadiusLabel => '1km';

  static String bundleCardDetailLine(int priceKrw) =>
      '${formatKrw(priceKrw)}원 / 반경1km / 노출지역 선택가능';

  static String krwSuffix(int amount) => '${formatKrw(amount)}원';
}

class PushPackageBundleOffer {
  const PushPackageBundleOffer({
    required this.id,
    required this.label,
    required this.packageCount,
    required this.priceKrw,
    required this.discountPercent,
    required this.marketingLine,
    this.extraBenefitLines = const [],
  });

  final String id;
  final String label;
  final int packageCount;
  final int priceKrw;
  final int discountPercent;
  final String marketingLine;
  final List<String> extraBenefitLines;

  int get unitPriceKrw => (priceKrw / packageCount).round();

  String get cardDetailLine =>
      PushPackageCatalog.bundleCardDetailLine(priceKrw);

  String get priceLabel => PushPackageCatalog.krwSuffix(priceKrw);

  String get productName =>
      packageCount == 1 ? PushPackageCatalog.singlePackageLabel : label;
}
