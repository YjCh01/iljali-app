import 'dart:math' as math;



import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';



/// 지역 푸시권 — 1회 = 추가 모집지역 푸시 1곳 (공고 등록 무료 · 황금핀은 100회 팩)

abstract final class PushWalletCreditPolicy {

  static bool isRecruitmentZoneIndex(int index) => index > 0;



  static int recruitmentZoneCount(JobPostNotificationSettings? settings) {

    if (settings == null || !settings.hasConfiguredBase) return 0;

    return settings.basePoints.length > 1 ? settings.basePoints.length - 1 : 0;

  }



  static int recruitmentZoneCountFromPoints(List<PushNotificationBasePoint> points) =>

      points.length > 1 ? points.length - 1 : 0;



  /// 현재 공고 기준 최대 노출 지점 — 근무지 1 + 이미 둔 모집지역 + 잔여 푸시권

  static int effectiveMaxExposurePoints({

    required EmployerPushWallet wallet,

    required int currentPointsLength,

  }) {

    final recruitZones =

        currentPointsLength > 1 ? currentPointsLength - 1 : 0;

    return PushPackageCatalog.baseLocationSlots +

        recruitZones +

        wallet.packageCredits;

  }



  /// 모집지역 설정 시트 — 최대 노출 지점 (근무지 1 + 모집지역)

  static int configureModeMaxPoints({

    required int pointsLength,

    required int availableCredits,

    int? walletTotalLocationSlots,

    EmployerPushWallet? wallet,

  }) {

    if (wallet != null) {

      return math.max(

        pointsLength,

        effectiveMaxExposurePoints(

          wallet: wallet,

          currentPointsLength: pointsLength,

        ),

      );

    }

    final recruitZones = pointsLength > 1 ? pointsLength - 1 : 0;

    final cap = PushPackageCatalog.baseLocationSlots +

        recruitZones +

        availableCredits;

    return math.max(pointsLength, cap);

  }



  /// 모집지역 설정 시트 — 잔여 공고 등록권 (모집지역 수와 무관)

  static int configurePreviewRemainingCredits({

    required int availableCredits,

    required int recruitZoneCount,

  }) =>

      availableCredits;



  /// 추가 가능 모집지역 — 노출 슬롯·지역 푸시권 모두 필요

  static int configureRemainingAddSlots({

    required int slotRemaining,

    required int availableCredits,

    required int recruitZoneCount,

  }) =>

      math.min(slotRemaining, availableCredits);



  /// 공고 카드 형광 배지 — 패키지 발송권만 (일일 무료 제외)

  static int jobPostCardDisplayCredits({

    required EmployerPushWallet wallet,

    required JobPostNotificationSettings? settings,

  }) =>

      wallet.packageRecruitCredits;



  /// 공고 카드 배지 — 패키지·오늘 무료 분리 표시

  static JobPostCardCreditsDisplay jobPostCardCredits({

    required EmployerPushWallet wallet,

  }) =>

      JobPostCardCreditsDisplay(

        packageCredits: wallet.packageRecruitCredits,

        dailyFreeAvailable: wallet.dailyFreePostingAvailable,

      );



  /// 설정된 모집지역 수 (표시용)

  static int registrationRecruitZoneCount(

    JobPostNotificationSettings? settings,

  ) =>

      recruitmentZoneCount(settings);



  /// 공고 등록 — 항상 무료 (크레딧 소진 없음)

  static int registrationPostingRightsRequired(EmployerPushWallet wallet) => 0;



  /// 공고 등록·수정 시 — 무료 등록 + 일일 무료 푸시 안내

  static PushRegistrationCostSummary registrationCost({

    required JobPostNotificationSettings settings,

    required EmployerPushWallet wallet,

  }) {

    return PushRegistrationCostSummary(

      configuredRecruitZones: registrationRecruitZoneCount(settings),

      postingRightsRequired: 0,

      usesDailyFreeWorkplace: wallet.dailyFreePostingAvailable,

    );

  }



  static bool canAffordRegistration({

    required JobPostNotificationSettings settings,

    required EmployerPushWallet wallet,

  }) {

    if (settings.basePoints.length >

        effectiveMaxExposurePoints(

          wallet: wallet,

          currentPointsLength: settings.basePoints.length,

        )) {

      return false;

    }

    return true;

  }



  /// 공고관리 「모집하기」 — 근무지: 하루 1회 무료 푸시 · 모집지역: 지역 푸시권 1회/곳

  static QuickRecruitDispatchCost quickRecruitDispatchCost({

    required JobPostNotificationSettings settings,

    required EmployerPushWallet wallet,

  }) {

    final recruitZones = recruitmentZoneCount(settings);

    if (recruitZones > 0) {

      return QuickRecruitDispatchCost(

        recruitmentZones: recruitZones,

        packageCreditsRequired: recruitZones,

      );

    }

    final usesDailyFree = wallet.dailyFreePostingAvailable;

    return QuickRecruitDispatchCost(

      recruitmentZones: 0,

      packageCreditsRequired: usesDailyFree ? 0 : 1,

      usesDailyFreeWorkplace: usesDailyFree,

    );

  }



  static bool canAffordQuickRecruit({

    required JobPostNotificationSettings settings,

    required EmployerPushWallet wallet,

  }) {

    if (settings.basePoints.length >

        effectiveMaxExposurePoints(

          wallet: wallet,

          currentPointsLength: settings.basePoints.length,

        )) {

      return false;

    }

    final cost = quickRecruitDispatchCost(settings: settings, wallet: wallet);

    return wallet.packageCredits >= cost.packageCreditsRequired;

  }



  static bool pointsEqual(PushNotificationBasePoint a, PushNotificationBasePoint b) {

    return a.coordinate.latitude == b.coordinate.latitude &&

        a.coordinate.longitude == b.coordinate.longitude &&

        a.radiusTier == b.radiusTier &&

        a.id == b.id;

  }



  /// 공고관리 — 지역 변경 후 푸시 발송 시 차감 (유지+수정+추가−삭제, 모집지역만)

  static ZonePushCreditSummary extraPushCreditsRequired({

    required List<PushNotificationBasePoint> before,

    required List<PushNotificationBasePoint> after,

  }) {

    final beforeRecruit = _recruitmentById(before);

    final afterRecruit = _recruitmentById(after);



    var maintained = 0;

    var modified = 0;

    var added = 0;

    var deleted = 0;



    for (final id in beforeRecruit.keys) {

      if (!afterRecruit.containsKey(id)) {

        deleted++;

      }

    }



    for (final entry in afterRecruit.entries) {

      final id = entry.key;

      final afterPoint = entry.value;

      if (!beforeRecruit.containsKey(id)) {

        added++;

        continue;

      }

      if (pointsEqual(beforeRecruit[id]!, afterPoint)) {

        maintained++;

      } else {

        modified++;

      }

    }



    final structureChanged = deleted > 0 || added > 0 || modified > 0;

    final billable = structureChanged ? afterRecruit.length : 0;



    return ZonePushCreditSummary(

      maintained: maintained,

      modified: modified,

      added: added,

      deleted: deleted,

      billableCredits: billable,

      structureChanged: structureChanged,

    );

  }



  static int extraPushBillableCredits({

    required List<PushNotificationBasePoint> before,

    required List<PushNotificationBasePoint> after,

    required int activePointIndex,

  }) {

    final summary = extraPushCreditsRequired(before: before, after: after);

    if (!summary.structureChanged) {

      return singleZonePushCredits(activePointIndex);

    }

    return summary.billableCredits;

  }



  /// 구조 변경 없이 단일 지역 재발송

  static int singleZonePushCredits(int activeIndex) =>

      isRecruitmentZoneIndex(activeIndex) ? 1 : 0;



  static int maxExposurePoints(

    EmployerPushWallet wallet, {

    int currentPointsLength = 1,

  }) =>

      effectiveMaxExposurePoints(

        wallet: wallet,

        currentPointsLength: currentPointsLength,

      );



  static JobPostNotificationSettings clampNotificationSettings(

    JobPostNotificationSettings settings,

    EmployerPushWallet wallet,

  ) {

    final max = maxExposurePoints(
      wallet,
      currentPointsLength: settings.basePoints.length,
    );

    if (settings.basePoints.length <= max) return settings;

    return settings.copyWith(

      basePoints: List.unmodifiable(settings.basePoints.take(max).toList()),

      maxBasePointsAllowed: max,

    );

  }



  static String actionButtonCreditsLabel(EmployerPushWallet wallet) {

    final pkg = wallet.packageRecruitCredits;

    if (pkg <= 0 && !wallet.dailyFreePostingAvailable) return '지역 푸시권 0회';

    if (pkg <= 0) return '근무지 무료 푸시 1회/일';

    return '지역 푸시권 $pkg회';

  }



  static String actionButtonCreditsDetail(EmployerPushWallet wallet) {

    if (!wallet.hasUsablePush) {

      return '지역 푸시권 구매 시 즉시 충전';

    }

    return wallet.recruitCreditsDetailLabel;

  }



  static Map<String, PushNotificationBasePoint> _recruitmentById(

    List<PushNotificationBasePoint> points,

  ) {

    final map = <String, PushNotificationBasePoint>{};

    for (var i = 0; i < points.length; i++) {

      if (isRecruitmentZoneIndex(i)) {

        map[points[i].id] = points[i];

      }

    }

    return map;

  }

}



/// 공고 카드 — 패키지·일일 무료 분리 (합산 「푸시알림 이용권」 금지)

class JobPostCardCreditsDisplay {

  const JobPostCardCreditsDisplay({

    required this.packageCredits,

    required this.dailyFreeAvailable,

  });



  final int packageCredits;

  final bool dailyFreeAvailable;



  bool get hasPackageCredits => packageCredits > 0;



  bool get showChip => hasPackageCredits;



  /// 형광 배지 — 유료 지역 푸시권만 (일일 무료 근무지 푸시는 카드 배지에 표시 안 함)

  String get chipLabel {

    if (hasPackageCredits) {

      return '지역 푸시권 $packageCredits회 보유중';

    }

    return '';

  }



  /// 계정 단위 — 근무지 1km 하루 1회 무료 푸시 (공고 등록 무료와 별개)

  String? get accountFreePushHint {

    if (!dailyFreeAvailable) return null;

    return '근무지 1km · 오늘 무료 푸시 1회 남음';

  }

}



/// 공고관리 「모집하기」 푸시 발송 — 모집지역 N곳 = 패키지 N회

class QuickRecruitDispatchCost {

  const QuickRecruitDispatchCost({

    required this.recruitmentZones,

    required this.packageCreditsRequired,

    this.usesDailyFreeWorkplace = false,

  });



  final int recruitmentZones;

  final int packageCreditsRequired;

  final bool usesDailyFreeWorkplace;



  String purchasePromptMessage({required int packageCreditsHeld}) {

    if (recruitmentZones > 0) {

      return '모집지역 $recruitmentZones곳에 푸시를 보내려면 지역 푸시권 $packageCreditsRequired회가 필요합니다. '

          '(보유 $packageCreditsHeld회) '

          '모집지역을 줄이거나 지역 푸시권을 추가 구매해 주세요.';

    }

    return '오늘 무료 근무지 푸시를 이미 사용했습니다. 근무지 푸시에 지역 푸시권 1회가 필요합니다.';

  }

}



/// 공고 등록·수정 시 패키지 발송권 산정

class PushRegistrationCostSummary {

  const PushRegistrationCostSummary({

    required this.configuredRecruitZones,

    required this.postingRightsRequired,

    required this.usesDailyFreeWorkplace,

  });



  final int configuredRecruitZones;

  final int postingRightsRequired;

  final bool usesDailyFreeWorkplace;



  int get packageCreditsRequired => postingRightsRequired;



  bool get needsPackagePurchase => packageCreditsRequired > 0;



  String get formPreviewLine {
    final zones = configuredRecruitZones > 0
        ? ' · 모집지역 $configuredRecruitZones곳 설정됨'
        : '';
    if (usesDailyFreeWorkplace) {
      return '공고 등록 무료 · 하루 1회 무료 푸시 (${PushPackageCatalog.planFreeRadiusSummary})$zones';
    }
    return '공고 등록 무료 · 근무지 무료 푸시 소진$zones';
  }

  String get purchasePromptMessage =>
      '공고 등록은 무료입니다. 모집지역 푸시는 지역 푸시권이 필요합니다.';

}



class ZonePushCreditSummary {

  const ZonePushCreditSummary({

    required this.maintained,

    required this.modified,

    required this.added,

    required this.deleted,

    required this.billableCredits,

    required this.structureChanged,

  });



  final int maintained;

  final int modified;

  final int added;

  final int deleted;

  final int billableCredits;

  final bool structureChanged;



  String get detailLabel {

    if (!structureChanged) return '';

    return '유지 $maintained · 수정 $modified · 추가 $added · 삭제 $deleted';

  }

}


