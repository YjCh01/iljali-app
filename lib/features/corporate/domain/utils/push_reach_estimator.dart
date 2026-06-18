import 'dart:math' as math;

import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// PUSH 발송 완료 화면 인자
class PushDispatchArgs {
  const PushDispatchArgs({
    required this.radiusTier,
    this.recruitmentSlotCount = 1,
    this.reachSeed,
    this.jobPostId,
    this.jobTitle,
    this.companyName,
    this.targetLabel,
    this.targetKind,
  });

  final PushRadiusTier radiusTier;
  /// @deprecated 단일 대상 발송 — [targetLabel] 사용
  final int recruitmentSlotCount;
  final int? reachSeed;
  final String? jobPostId;
  final String? jobTitle;
  final String? companyName;
  final String? targetLabel;
  final PushDispatchTargetKind? targetKind;
}

/// 예상 PUSH 도달 인원 (MVP mock — 추후 서버 집계로 교체)
///
/// **모집권 1개 = 20~25명** (지역별 독립 발송 가정).
abstract final class PushReachEstimator {
  static const minReachPerSlot = 20;
  static const maxReachPerSlot = 25;

  /// 모집권(노출·모집 지역) 수 기준 — 등록·발송 완료 UI용
  static int estimateRecruitmentRights(
    int slotCount, {
    int? seed,
  }) {
    if (slotCount <= 0) return 0;
    final rng = math.Random(seed ?? slotCount * 9973 + 42);
    var total = 0;
    for (var i = 0; i < slotCount; i++) {
      total += minReachPerSlot +
          rng.nextInt(maxReachPerSlot - minReachPerSlot + 1);
    }
    return total;
  }

  static int estimateForSettings(
    JobPostNotificationSettings settings, {
    int? seed,
  }) {
    return estimateRecruitmentRights(
      recruitmentSlotCountFromSettings(settings),
      seed: seed,
    );
  }

  static int recruitmentSlotCountFromSettings(
    JobPostNotificationSettings settings,
  ) {
    if (settings.basePoints.isEmpty) return 1;
    final active = settings.basePoints
        .where((p) => p.radiusMeters > 0)
        .length;
    return active > 0 ? active : settings.basePoints.length;
  }

  /// @deprecated 반경 단일 추정 — [estimateRecruitmentRights] 사용
  static int estimate(PushRadiusTier tier) {
    final meters = tier.radiusMeters;
    if (meters <= 0) return 0;
    return estimateRecruitmentRights(1);
  }
}
