import 'dart:math' as math;

import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// 일자리 알림핀 — 1회 = 근무지·모집지역 PUSH 1곳 (공고 등록 무료)
abstract final class PushWalletCreditPolicy {
  static bool isRecruitmentZoneIndex(int index) => index > 0;

  static int recruitmentZoneCount(JobPostNotificationSettings? settings) {
    if (settings == null || !settings.hasConfiguredBase) return 0;
    return settings.basePoints.length > 1 ? settings.basePoints.length - 1 : 0;
  }

  static int recruitmentZoneCountFromPoints(
    List<PushNotificationBasePoint> points,
  ) =>
      points.length > 1 ? points.length - 1 : 0;

  /// 현재 공고 기준 최대 노출 지점 — 근무지 1 + 이미 둔 모집지역 + 잔여 알림핀
  static int effectiveMaxExposurePoints({
    required EmployerPushWallet wallet,
    required int currentPointsLength,
  }) {
    final recruitZones =
        currentPointsLength > 1 ? currentPointsLength - 1 : 0;
    return PushPackageCatalog.baseLocationSlots +
        recruitZones +
        wallet.packageCredits +
        wallet.exposurePushBundleCredits;
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

  /// 추가 가능 모집지역 — 노출 슬롯·일자리 알림핀 모두 필요 (즉시 발송·결제 연동)
  static int configureRemainingAddSlots({
    required int slotRemaining,
    required int availableCredits,
    required int recruitZoneCount,
  }) =>
      math.min(slotRemaining, availableCredits);

  /// 설정 화면 — 크레딧 없이 미리 배치 (노출·결제는 유료 서비스에서 별도)
  static int configurePreviewRemainingAddSlots({
    required int pointsLength,
    required int previewRecruitmentPinCap,
  }) {
    final recruitCount = pointsLength > 1 ? pointsLength - 1 : 0;
    final previewRemaining = previewRecruitmentPinCap - recruitCount;
    if (previewRemaining <= 0) return 0;
    final hardCap =
        previewRecruitmentPinCap + PushPackageCatalog.baseLocationSlots;
    final lengthRemaining = hardCap - pointsLength;
    if (lengthRemaining <= 0) return 0;
    return math.min(previewRemaining, lengthRemaining);
  }

  /// 공고 카드 형광 배지 — 일자리 알림핀만
  static int jobPostCardDisplayCredits({
    required EmployerPushWallet wallet,
    required JobPostNotificationSettings? settings,
  }) =>
      wallet.packageRecruitCredits;

  /// 공고 카드 배지 — 일자리 알림핀
  static JobPostCardCreditsDisplay jobPostCardCredits({
    required EmployerPushWallet wallet,
  }) =>
      JobPostCardCreditsDisplay(
        packageCredits: wallet.packageRecruitCredits,
      );

  /// 설정된 모집지역 수 (표시용)
  static int registrationRecruitZoneCount(
    JobPostNotificationSettings? settings,
  ) =>
      recruitmentZoneCount(settings);

  /// 공고 등록 — 항상 무료 (크레딧 소진 없음)
  static int registrationPostingRightsRequired(EmployerPushWallet wallet) => 0;

  /// 공고 등록·수정 시 — 무료 등록 안내
  static PushRegistrationCostSummary registrationCost({
    required JobPostNotificationSettings settings,
    required EmployerPushWallet wallet,
  }) {
    return PushRegistrationCostSummary(
      configuredRecruitZones: registrationRecruitZoneCount(settings),
      postingRightsRequired: 0,
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

  /// 공고관리 「모집하기」 — 근무지·모집지역 각 1회 일자리 알림핀
  static QuickRecruitDispatchCost quickRecruitDispatchCost({
    required JobPostNotificationSettings settings,
    required EmployerPushWallet wallet,
  }) {
    final recruitZones = recruitmentZoneCount(settings);
    return QuickRecruitDispatchCost(
      recruitmentZones: recruitZones,
      recruitmentCreditsRequired: recruitZones,
      workplaceCreditsRequired: 1,
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
    return cost.canAffordFull(wallet);
  }

  static bool pointsEqual(
    PushNotificationBasePoint a,
    PushNotificationBasePoint b,
  ) {
    return a.coordinate.latitude == b.coordinate.latitude &&
        a.coordinate.longitude == b.coordinate.longitude &&
        a.radiusTier == b.radiusTier &&
        a.id == b.id;
  }

  /// 공고관리 — 지역 변경 후 PUSH 발송 시 차감 (유지+수정+추가−삭제, 모집지역만)
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
        if (!afterPoint.exposureActivated) {
          added++;
        }
        continue;
      }
      if (pointsEqual(beforeRecruit[id]!, afterPoint)) {
        maintained++;
      } else {
        modified++;
      }
    }

    final structureChanged = deleted > 0 ||
        added > 0 ||
        modified > 0 ||
        beforeRecruit.length != afterRecruit.length;
    final billable = structureChanged ? modified + added : 0;

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

  /// 구조 변경 없이 단일 지역 재발송 — 근무지·모집지역 모두 1회
  static int singleZonePushCredits(int activeIndex) => 1;

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
    if (pkg <= 0) return '일자리 알림핀 0회';
    return '일자리 알림핀 $pkg회';
  }

  static String actionButtonCreditsDetail(EmployerPushWallet wallet) {
    if (!wallet.hasUsablePush) {
      return '일자리 알림핀 구매 시 즉시 충전';
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

/// 공고 카드 — 일자리 알림핀 (합산 「PUSH알림 이용권」 금지)
class JobPostCardCreditsDisplay {
  const JobPostCardCreditsDisplay({
    required this.packageCredits,
  });

  final int packageCredits;

  bool get hasPackageCredits => packageCredits > 0;

  bool get showChip => hasPackageCredits;

  String get chipLabel {
    if (hasPackageCredits) {
      return '일자리 알림핀 $packageCredits회 보유중';
    }
    return '';
  }
}

/// 공고관리 「모집하기」 PUSH 발송 — 근무지 1 + 모집지역 N = 일자리 알림핀 N+1회
class QuickRecruitDispatchCost {
  const QuickRecruitDispatchCost({
    required this.recruitmentZones,
    required this.recruitmentCreditsRequired,
    required this.workplaceCreditsRequired,
  });

  final int recruitmentZones;
  final int recruitmentCreditsRequired;
  final int workplaceCreditsRequired;

  int get packageCreditsRequired =>
      recruitmentCreditsRequired + workplaceCreditsRequired;

  bool canAffordFull(EmployerPushWallet wallet) =>
      wallet.packageCredits >= packageCreditsRequired;

  String purchasePromptMessage({required int packageCreditsHeld}) {
    if (recruitmentZones > 0) {
      return '근무지 + 일자리 알림핀 $recruitmentZones곳 PUSH에 일자리 알림핀 '
          '$packageCreditsRequired회가 필요합니다. (보유 $packageCreditsHeld회)';
    }
    return '근무지 PUSH에 일자리 알림핀 1회가 필요합니다. (보유 $packageCreditsHeld회)';
  }
}

/// 공고 등록·수정 시 패키지 발송권 산정
class PushRegistrationCostSummary {
  const PushRegistrationCostSummary({
    required this.configuredRecruitZones,
    required this.postingRightsRequired,
  });

  final int configuredRecruitZones;
  final int postingRightsRequired;

  int get packageCreditsRequired => postingRightsRequired;

  bool get needsPackagePurchase => packageCreditsRequired > 0;

  String get formPreviewLine {
    final zones = configuredRecruitZones > 0
        ? ' · 일자리 알림핀 $configuredRecruitZones곳 설정됨'
        : '';
    return '근무지 주변 1km 무료 노출$zones';
  }

  String get purchasePromptMessage =>
      '일자리 알림핀 설정 시 이용권이 필요합니다.';
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
