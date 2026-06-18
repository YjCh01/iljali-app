import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 셔틀 노선 지도 노출 자격 — 노선 등록(무료) ≠ 지도 오버레이 활성화(유료).
///
/// [CorporateJobPost.hasShuttleRouteOverlay]가 true일 때만 구직자 지도에
/// 정류장·노선이 표시됩니다. 노선만 연결된 상태에서는 근무지 핀만 보입니다.
abstract final class ShuttleRouteEntitlement {
  static bool tierAllowsOverlay(JobMapPinDisplayTier tier) =>
      tier == JobMapPinDisplayTier.packageActive ||
      tier == JobMapPinDisplayTier.premiumPartner;

  static bool postEligible(CorporateJobPost post) {
    if (post.effectiveLinkedCommuteRouteIds.isEmpty) return false;
    return post.hasShuttleRouteOverlay;
  }
}
