import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';

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
          '${PushPackageCatalog.pushRadiusLabel} (일자리 알림핀)',
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
        PushRadiusTier.standardFree1km => '근무지 주변 1km · 현재 노출중.',
        PushRadiusTier.standard1km => '일자리 알림핀 주변 1km.',
        _ => '레거시 반경 — 근무지 1km/일자리 알림핀 1km 정책 사용을 권장합니다.',
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

/// PUSH 알림 거점 1곳
class PushNotificationBasePoint {
  const PushNotificationBasePoint({
    required this.id,
    required this.coordinate,
    required this.addressLabel,
    this.radiusTier = PushRadiusTier.standard1km,
    this.isPrimary = true,
    this.isPremiumSlot = false,
    this.isPaid = false,
    this.exposureActivated = false,
    this.activationCoordinate,
    this.exposurePaidAt,
  });

  final String id;
  final GeoCoordinate coordinate;
  final String addressLabel;
  final PushRadiusTier radiusTier;
  final bool isPrimary;
  final bool isPremiumSlot;
  final bool isPaid;

  /// 일자리 알림핀 이용권으로 노출 활성화됨 — 좌표 잠금
  final bool exposureActivated;

  /// 활성화 시점 좌표 (PUSH 단독 발송 검증용)
  final GeoCoordinate? activationCoordinate;

  /// 노출 결제 시각 — D+1 23:59:59까지 잠금
  final DateTime? exposurePaidAt;

  int get radiusMeters => radiusTier.radiusMeters;

  PushNotificationBasePoint copyWith({
    String? id,
    GeoCoordinate? coordinate,
    String? addressLabel,
    PushRadiusTier? radiusTier,
    bool? isPrimary,
    bool? isPremiumSlot,
    bool? isPaid,
    bool? exposureActivated,
    GeoCoordinate? activationCoordinate,
    DateTime? exposurePaidAt,
    bool clearActivationCoordinate = false,
    bool clearExposurePaidAt = false,
  }) {
    return PushNotificationBasePoint(
      id: id ?? this.id,
      coordinate: coordinate ?? this.coordinate,
      addressLabel: addressLabel ?? this.addressLabel,
      radiusTier: radiusTier ?? this.radiusTier,
      isPrimary: isPrimary ?? this.isPrimary,
      isPremiumSlot: isPremiumSlot ?? this.isPremiumSlot,
      isPaid: isPaid ?? this.isPaid,
      exposureActivated: exposureActivated ?? this.exposureActivated,
      activationCoordinate: clearActivationCoordinate
          ? null
          : activationCoordinate ?? this.activationCoordinate,
      exposurePaidAt:
          clearExposurePaidAt ? null : exposurePaidAt ?? this.exposurePaidAt,
    );
  }
}

extension PushNotificationBasePointExposureX on PushNotificationBasePoint {
  DateTime? get exposureExpiresAt => exposurePaidAt == null
      ? null
      : ShuttleExposurePolicy.expiresAtFromPayment(exposurePaidAt!);

  bool get isExposureLocked {
    if (!exposureActivated) return false;
    if (exposurePaidAt == null) return true;
    return ShuttleExposurePolicy.isActive(exposurePaidAt);
  }
}

/// 일자리 알림핀 표시명 — 0: 근무지(기본), 1+: 추가 알림핀(유료)
abstract final class ExposurePointLabels {
  static String title(int index) => switch (index) {
        0 => '근무지(기본)',
        _ => '일자리 알림핀 $index',
      };

  /// 목록·시트 행 부제 — 근무지는 공고 등록 시 자동 노출
  static String zoneRowSubtitle(int index) => '';

  /// 하단 「+」 행
  static String addZoneButtonLabel(int remainingAdds) {
    return '일자리 알림핀 추가';
  }

  static String compactLine(int index, PushNotificationBasePoint point) {
    final sub = zoneRowSubtitle(index);
    if (sub.isEmpty) return title(index);
    return '${title(index)} · $sub';
  }

  /// UI용 반경 — 「반경 주변」 중복 없음
  static String radiusUi(PushRadiusTier tier) {
    final label = tier.nearbyDisplayLabel;
    if (label == '주변' || label == '위치만') return label;
    return '반경 $label';
  }

  static String slotCount(int current, int max) => '$current/$max곳';
}

abstract final class NotificationPlanLimits {
  static int get maxBasePoints => PushPlanEnforcement.maxBasePointsSync;

  static PushRadiusTier get maxRadiusTier =>
      PushPlanEnforcement.defaultRadiusTier;

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
        DesignatedPointTier.onePoint => '근무지 1곳 · 일자리 알림핀은 설정 시 이용.',
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

/// PUSH 결제 묶음 — 일일 기본 한도 초과 시 추가 PUSH(add-on) 과금
class PushPaymentBundle {
  const PushPaymentBundle({
    required this.radiusTier,
    required this.pointTier,
    required this.spotCount,
    this.isExtraPush = false,
    this.extraPushFeeKrw = 0,
    this.paymentKind,
  });

  const PushPaymentBundle.extraPush({required int feeKrw})
      : radiusTier = PushRadiusTier.standard1km,
        pointTier = DesignatedPointTier.onePoint,
        spotCount = 1,
        isExtraPush = true,
        extraPushFeeKrw = feeKrw,
        paymentKind = JobPostPaymentRequestKind.extraPush;

  /// PUSH권 1곳·1회 발송
  const PushPaymentBundle.pushTicket({this.spotCount = 1})
      : radiusTier = PushRadiusTier.standard1km,
        pointTier = DesignatedPointTier.onePoint,
        isExtraPush = true,
        extraPushFeeKrw = PushTicketCatalog.unitPriceKrw * spotCount,
        paymentKind = JobPostPaymentRequestKind.pushTicket;

  /// 패키지 1회 구매
  const PushPaymentBundle.packagePurchase()
      : radiusTier = PushRadiusTier.standard1km,
        pointTier = DesignatedPointTier.onePoint,
        spotCount = 1,
        isExtraPush = true,
        extraPushFeeKrw = PushPackageCatalog.singlePackagePriceKrw,
        paymentKind = JobPostPaymentRequestKind.packagePurchase;

  final PushRadiusTier radiusTier;
  final DesignatedPointTier pointTier;
  final int spotCount;
  final bool isExtraPush;
  final int extraPushFeeKrw;
  final JobPostPaymentRequestKind? paymentKind;

  int get totalAmountKrw => isExtraPush ? extraPushFeeKrw : 0;

  bool get requiresPayment => isExtraPush && extraPushFeeKrw > 0;

  String get productSummary {
    if (!isExtraPush) {
      return 'PUSH ${radiusTier.shortLabel} · ${pointTier.shortLabel} (요금제 포함)';
    }
    return switch (paymentKind) {
      JobPostPaymentRequestKind.shuttleStopExposure => spotCount > 1
          ? '${PushPackageCatalog.shuttlePinProductName} $spotCount곳'
          : '${PushPackageCatalog.shuttlePinProductName} 1곳',
      JobPostPaymentRequestKind.jobPinExposure => spotCount > 1
          ? '${PushPackageCatalog.jobPinProductName} $spotCount곳'
          : '${PushPackageCatalog.jobPinProductName} 1곳',
      JobPostPaymentRequestKind.pushTicket => spotCount > 1
          ? '${PushTicketCatalog.productName} $spotCount회'
          : '${PushTicketCatalog.productName} 1회',
      JobPostPaymentRequestKind.packagePurchase => '알림핀 패키지 1회',
      JobPostPaymentRequestKind.extraPush => spotCount > 1
          ? '추가 PUSH $spotCount회'
          : '추가 PUSH 1회',
      null => spotCount > 1
          ? '${PushPackageCatalog.jobPinProductName} $spotCount곳'
          : '${PushPackageCatalog.jobPinProductName} 1곳',
    };
  }

  String get checkoutProductTitle {
    final summary = productSummary;
    return switch (paymentKind) {
      JobPostPaymentRequestKind.shuttleStopExposure =>
        '${PushPackageCatalog.shuttlePinProductName} · $summary',
      JobPostPaymentRequestKind.jobPinExposure =>
        '${PushPackageCatalog.jobPinProductName} · $summary',
      JobPostPaymentRequestKind.pushTicket =>
        '${PushTicketCatalog.productName} · $summary',
      JobPostPaymentRequestKind.packagePurchase => '알림핀 패키지 · $summary',
      JobPostPaymentRequestKind.extraPush => '푸시 알림 · $summary',
      null => '${PushPackageCatalog.jobPinProductName} · $summary',
    };
  }

  String get checkoutProductDetail {
    if (!isExtraPush) {
      return '반경 ${radiusTier.label}\n'
          '지정 ${pointTier.label} · $spotCount곳';
    }
    return switch (paymentKind) {
      JobPostPaymentRequestKind.shuttleStopExposure =>
        '선택한 정류장을 구직자 지도에 노출합니다.\n'
        '노출 기간: ${PushPackageCatalog.exposureEndsLabel}',
      JobPostPaymentRequestKind.jobPinExposure =>
        '선택한 일자리 알림핀을 구직자 지도에 노출합니다.\n'
        '노출 기간: ${PushPackageCatalog.exposureEndsLabel}',
      JobPostPaymentRequestKind.pushTicket =>
        '알림핀·정류장 1곳 선택 후 PUSH 1회 발송',
      JobPostPaymentRequestKind.packagePurchase =>
        '거점 1 + 푸시 1 (반경 1km)',
      JobPostPaymentRequestKind.extraPush =>
        '기본 일일 푸시 한도 초과 · 패키지 1회 발송\n'
        '추가 공고 노출 범위·지원자 모집하기는 패키지 구매로 확장',
      null =>
        '선택한 위치를 구직자 지도에 노출합니다.\n'
        '노출 기간: ${PushPackageCatalog.exposureEndsLabel}',
    };
  }

  String get checkoutBreakdownLabel => switch (paymentKind) {
        JobPostPaymentRequestKind.shuttleStopExposure => '정류장 표시핀 노출',
        JobPostPaymentRequestKind.jobPinExposure => '일자리 알림핀 노출',
        JobPostPaymentRequestKind.pushTicket => PushTicketCatalog.productName,
        JobPostPaymentRequestKind.packagePurchase => '알림핀 패키지',
        JobPostPaymentRequestKind.extraPush => '지원자 모집하기 (add-on)',
        null => '일자리 알림핀 노출',
      };

  Map<String, dynamic> toJson() => {
        'radiusTier': radiusTier.name,
        'pointTier': pointTier.name,
        'spotCount': spotCount,
        'isExtraPush': isExtraPush,
        'extraPushFeeKrw': extraPushFeeKrw,
        if (paymentKind != null) 'paymentKind': paymentKind!.name,
      };

  factory PushPaymentBundle.fromJson(Map<String, dynamic> json) {
    PushRadiusTier parseRadius(String? raw) {
      if (raw == null) return PushRadiusTier.standard1km;
      try {
        return PushRadiusTier.values.byName(raw);
      } on ArgumentError {
        return PushRadiusTier.standard1km;
      }
    }

    DesignatedPointTier parsePoint(String? raw) {
      if (raw == null) return DesignatedPointTier.onePoint;
      try {
        return DesignatedPointTier.values.byName(raw);
      } on ArgumentError {
        return DesignatedPointTier.onePoint;
      }
    }

    return PushPaymentBundle(
      radiusTier: parseRadius(json['radiusTier'] as String?),
      pointTier: parsePoint(json['pointTier'] as String?),
      spotCount: json['spotCount'] as int? ?? 1,
      isExtraPush: json['isExtraPush'] as bool? ?? true,
      extraPushFeeKrw: json['extraPushFeeKrw'] as int? ?? 0,
      paymentKind: json['paymentKind'] != null
          ? parseJobPostPaymentRequestKind(json['paymentKind'] as String?)
          : null,
    );
  }
}

/// 일자리 공고별 PUSH 알림 설정
class JobPostNotificationSettings {
  JobPostNotificationSettings({
    this.basePoints = const [],
    this.pushCountLimit = 999,
    this.pushCountUsed = 0,
    int? maxBasePointsAllowed,
    this.paymentCompleted = false,
    this.designatedPointTier = DesignatedPointTier.onePoint,
    this.spotPaymentCompleted = false,
  })  : maxBasePointsAllowed =
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

  /// 카드·상세 — 근무지 / 모집지역 N + 고정 부제
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
