import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';

/// 반경 등급 (km / m 단위)
enum PushRadiusTier {
  radius0km,
  standardFree1km,
  standard1km,
  extended3km,
  extended5km,
  extended7km,
}

extension PushRadiusTierX on PushRadiusTier {
  int get radiusKm => switch (this) {
        PushRadiusTier.radius0km => 0,
        PushRadiusTier.standardFree1km => 0,
        PushRadiusTier.standard1km => 1,
        PushRadiusTier.extended3km => 3,
        PushRadiusTier.extended5km => 5,
        PushRadiusTier.extended7km => 7,
      };

  int get radiusMeters => switch (this) {
        PushRadiusTier.radius0km => 0,
        PushRadiusTier.standardFree1km => PushPackageCatalog.freePushRadiusM,
        PushRadiusTier.standard1km => PushPackageCatalog.packagePushRadiusM,
        PushRadiusTier.extended3km => 3000,
        PushRadiusTier.extended5km => 5000,
        PushRadiusTier.extended7km => 7000,
      };

  String get label => switch (this) {
        PushRadiusTier.radius0km => '0km (위치만)',
        PushRadiusTier.standardFree1km =>
          PushPackageCatalog.pushRadiusLabel,
        PushRadiusTier.standard1km =>
          '${PushPackageCatalog.pushRadiusLabel} (패키지 크레딧)',
        PushRadiusTier.extended3km => '3km',
        PushRadiusTier.extended5km => '5km',
        PushRadiusTier.extended7km => '7km',
      };

  String get shortLabel => switch (this) {
        PushRadiusTier.radius0km => '0km',
        PushRadiusTier.standardFree1km => '주변',
        PushRadiusTier.standard1km => '주변',
        PushRadiusTier.extended3km => '3km',
        PushRadiusTier.extended5km => '5km',
        PushRadiusTier.extended7km => '7km',
      };

  /// UI 노출용 — 1km 구간은 「주변」
  String get nearbyDisplayLabel => switch (this) {
        PushRadiusTier.radius0km => '위치만',
        PushRadiusTier.standardFree1km => '주변',
        PushRadiusTier.standard1km => '주변',
        _ => shortLabel,
      };

  String get description => switch (this) {
        PushRadiusTier.radius0km => '지도 위치만 저장하고 알림 반경은 설정하지 않습니다.',
        PushRadiusTier.standardFree1km =>
            '기본 플랜 — ${PushPackageCatalog.pushRadiusLabel} · 하루 ${PushPackageCatalog.dailyFreePush}회.',
        PushRadiusTier.standard1km =>
            '패키지 알림 — 노출 범위 기준 1km. 더 넓은 커버는 공고 노출 범위 추가(패키지).',
        _ => '레거시 반경 — 패키지 노출 범위 사용을 권장합니다.',
      };

  bool get isPaid => false;
  int get priceKrw => 0;
}

abstract final class PushRadiusOptions {
  static const selectableTiers = [
    PushRadiusTier.standardFree1km,
    PushRadiusTier.standard1km,
  ];

  static const sliderKmSteps = [0, 1];

  static PushRadiusTier fromKm(int km) => switch (km) {
        0 => PushRadiusTier.standardFree1km,
        1 => PushRadiusTier.standard1km,
        _ => PushRadiusTier.standardFree1km,
      };

  static PushRadiusTier fromMeters(int meters) {
    if (meters <= PushPackageCatalog.freePushRadiusM) {
      return PushRadiusTier.standardFree1km;
    }
    return PushRadiusTier.standard1km;
  }
}

/// 푸시 알림 거점 1곳
class PushNotificationBasePoint {
  const PushNotificationBasePoint({
    required this.id,
    required this.coordinate,
    required this.addressLabel,
    this.radiusTier = PushRadiusTier.standard1km,
    this.isPrimary = true,
    this.isPremiumSlot = false,
    this.isPaid = false,
  });

  final String id;
  final GeoCoordinate coordinate;
  final String addressLabel;
  final PushRadiusTier radiusTier;
  final bool isPrimary;
  final bool isPremiumSlot;
  final bool isPaid;

  int get radiusMeters => radiusTier.radiusMeters;

  PushNotificationBasePoint copyWith({
    String? id,
    GeoCoordinate? coordinate,
    String? addressLabel,
    PushRadiusTier? radiusTier,
    bool? isPrimary,
    bool? isPremiumSlot,
    bool? isPaid,
  }) {
    return PushNotificationBasePoint(
      id: id ?? this.id,
      coordinate: coordinate ?? this.coordinate,
      addressLabel: addressLabel ?? this.addressLabel,
      radiusTier: radiusTier ?? this.radiusTier,
      isPrimary: isPrimary ?? this.isPrimary,
      isPremiumSlot: isPremiumSlot ?? this.isPremiumSlot,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

/// 노출·모집 지역 표시명 — 0: 근무지, 1+: 모집지역 N
abstract final class ExposurePointLabels {
  static String title(int index) => switch (index) {
        0 => '근무지',
        _ => '모집지역 $index',
      };

  /// UI용 반경 — 「반경 주변」 중복 없음
  static String radiusUi(PushRadiusTier tier) {
    final label = tier.nearbyDisplayLabel;
    if (label == '주변' || label == '위치만') return label;
    return '반경 $label';
  }

  static String slotCount(int current, int max) => '$current/$max곳';

  /// 카드·목록용 — 「근무지 · 주변」「모집지역 1 · 주변」
  static String compactLine(int index, PushNotificationBasePoint point) {
    return '${title(index)} · ${radiusUi(point.radiusTier)}';
  }
}

abstract final class NotificationPlanLimits {
  static int get maxBasePoints => PushPlanEnforcement.maxBasePointsSync;

  static int get dailyPushLimit => PushPlanEnforcement.dailyPushLimit;

  static PushRadiusTier get maxRadiusTier =>
      PushPlanEnforcement.defaultFreeRadiusTier;

  static int get extraPushPriceKrw => PushPlanEnforcement.extraPushPriceKrw;
}
/// 지정 포인트 등급 — 요금제별 포함 한도
enum DesignatedPointTier {
  onePoint,
  twoPoints,
  fivePoints,
  unlimited,
}

extension DesignatedPointTierX on DesignatedPointTier {
  int get maxPoints => switch (this) {
        DesignatedPointTier.onePoint => 1,
        DesignatedPointTier.twoPoints => 2,
        DesignatedPointTier.fivePoints => 5,
        DesignatedPointTier.unlimited => 999,
      };

  String get label => switch (this) {
        DesignatedPointTier.onePoint => '1곳 (기본)',
        DesignatedPointTier.twoPoints => '2곳',
        DesignatedPointTier.fivePoints => '5곳',
        DesignatedPointTier.unlimited => '무제한',
      };

  String get shortLabel => switch (this) {
        DesignatedPointTier.onePoint => '1곳',
        DesignatedPointTier.twoPoints => '2곳',
        DesignatedPointTier.fivePoints => '5곳',
        DesignatedPointTier.unlimited => '무제한',
      };

  bool get isPaid => false;

  int get priceKrw => 0;

  String get description => switch (this) {
        DesignatedPointTier.onePoint => '기본 노출 범위 1곳 · 패키지로 추가.',
        DesignatedPointTier.twoPoints => '노출 범위 2곳.',
        DesignatedPointTier.fivePoints => '노출 범위 5곳.',
        DesignatedPointTier.unlimited => '노출 범위 무제한.',
      };

  int get maxPointsFromWallet => PushPlanEnforcement.maxBasePointsSync;
}

abstract final class DesignatedPointOptions {
  static const selectableTiers = [
    DesignatedPointTier.onePoint,
    DesignatedPointTier.twoPoints,
    DesignatedPointTier.fivePoints,
    DesignatedPointTier.unlimited,
  ];
}

/// 푸시 결제 묶음 — 일일 기본 한도 초과 시 추가 푸시(add-on) 과금
class PushPaymentBundle {
  const PushPaymentBundle({
    required this.radiusTier,
    required this.pointTier,
    required this.spotCount,
    this.isExtraPush = false,
    this.extraPushFeeKrw = 0,
  });

  const PushPaymentBundle.extraPush({required int feeKrw})
      : radiusTier = PushRadiusTier.standard1km,
        pointTier = DesignatedPointTier.onePoint,
        spotCount = 1,
        isExtraPush = true,
        extraPushFeeKrw = feeKrw;

  /// 패키지 1회 구매
  const PushPaymentBundle.packagePurchase()
      : radiusTier = PushRadiusTier.standard1km,
        pointTier = DesignatedPointTier.onePoint,
        spotCount = 1,
        isExtraPush = true,
        extraPushFeeKrw = PushPackageCatalog.singlePackagePriceKrw;

  final PushRadiusTier radiusTier;
  final DesignatedPointTier pointTier;
  final int spotCount;
  final bool isExtraPush;
  final int extraPushFeeKrw;

  int get totalAmountKrw => isExtraPush ? extraPushFeeKrw : 0;

  bool get requiresPayment => isExtraPush && extraPushFeeKrw > 0;

  String get productSummary {
    if (isExtraPush) {
      return '공고 노출·모집 패키지 1회';
    }
    return '푸시 ${radiusTier.shortLabel} · ${pointTier.shortLabel} (요금제 포함)';
  }
}

/// 일자리 공고별 푸시 알림 설정
class JobPostNotificationSettings {
  JobPostNotificationSettings({
    this.basePoints = const [],
    int? pushCountLimit,
    this.pushCountUsed = 0,
    int? maxBasePointsAllowed,
    this.paymentCompleted = false,
    this.designatedPointTier = DesignatedPointTier.onePoint,
    this.spotPaymentCompleted = false,
  })  : pushCountLimit =
            pushCountLimit ?? NotificationPlanLimits.dailyPushLimit,
        maxBasePointsAllowed =
            maxBasePointsAllowed ?? NotificationPlanLimits.maxBasePoints;

  final List<PushNotificationBasePoint> basePoints;
  final int pushCountLimit;
  final int pushCountUsed;
  final int maxBasePointsAllowed;
  final bool paymentCompleted;
  final DesignatedPointTier designatedPointTier;
  final bool spotPaymentCompleted;

  bool get hasConfiguredBase => basePoints.isNotEmpty;

  PushNotificationBasePoint? get primaryBase =>
      basePoints.isEmpty ? null : basePoints.first;

  PushRadiusTier? get selectedRadiusTier => primaryBase?.radiusTier;

  bool get requiresRadiusPayment => false;

  bool get requiresSpotPayment => false;

  bool get requiresPayment => false;

  PushPaymentBundle get paymentBundle => PushPaymentBundle(
        radiusTier: primaryBase?.radiusTier ?? PushRadiusTier.standard1km,
        pointTier: designatedPointTier,
        spotCount: basePoints.length,
      );

  int get paymentAmountKrw => paymentBundle.totalAmountKrw;

  bool get canAddMoreBasePoints =>
      basePoints.length < maxBasePointsAllowed;

  int get remainingPushCount =>
      (pushCountLimit - pushCountUsed).clamp(0, pushCountLimit);

  bool get isAtDailyPushLimit => remainingPushCount <= 0;

  int get extraPushPriceKrw => NotificationPlanLimits.extraPushPriceKrw;

  String get summaryLabel {
    if (!hasConfiguredBase) return '미설정';
    if (basePoints.length == 1) {
      return exposurePointLabels.first;
    }
    return exposurePointLabels.join(' · ');
  }

  /// 카드·상세 — 근무지 반경 내 / 모집 지역 N · 주소 · 주변
  List<String> get exposurePointLabels => [
        for (var i = 0; i < basePoints.length; i++)
          ExposurePointLabels.compactLine(i, basePoints[i]),
      ];

  JobPostNotificationSettings copyWith({
    List<PushNotificationBasePoint>? basePoints,
    int? pushCountLimit,
    int? pushCountUsed,
    int? maxBasePointsAllowed,
    bool? paymentCompleted,
    DesignatedPointTier? designatedPointTier,
    bool? spotPaymentCompleted,
  }) {
    return JobPostNotificationSettings(
      basePoints: basePoints ?? this.basePoints,
      pushCountLimit: pushCountLimit ?? this.pushCountLimit,
      pushCountUsed: pushCountUsed ?? this.pushCountUsed,
      maxBasePointsAllowed:
          maxBasePointsAllowed ?? this.maxBasePointsAllowed,
      paymentCompleted: paymentCompleted ?? this.paymentCompleted,
      designatedPointTier:
          designatedPointTier ?? this.designatedPointTier,
      spotPaymentCompleted:
          spotPaymentCompleted ?? this.spotPaymentCompleted,
    );
  }
}
