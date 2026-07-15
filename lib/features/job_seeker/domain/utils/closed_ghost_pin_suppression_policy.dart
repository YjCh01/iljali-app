import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';
import 'package:map/features/job_seeker/domain/factories/closed_ghost_job_map_pin_factory.dart';

/// 마감유령핀 — 같은 근무지에 채용 중 공고가 있으면 숨김 (복사·재등록 후 겹침 방지)
abstract final class ClosedGhostPinSuppressionPolicy {
  static bool shouldRenderGhostForPost({
    required CorporateJobPost post,
    required List<CorporateJobPost> allPosts,
  }) {
    if (!ClosedGhostJobMapPinFactory.qualifiesExpiredFreePost(post)) {
      return false;
    }
    return !hasActiveReplacementAtWorkplace(
      closedPost: post,
      allPosts: allPosts,
    );
  }

  static bool hasActiveReplacementAtWorkplace({
    required CorporateJobPost closedPost,
    required List<CorporateJobPost> allPosts,
  }) {
    final companyKey = closedPost.registeredBy?.companyKey?.trim();
    if (companyKey == null || companyKey.isEmpty) return false;

    final closedWorkplaceId = closedPost.workplaceId?.trim();
    final closedCoord = _workplaceCoordinate(closedPost);
    final closedWarehouse = closedPost.warehouseName.trim();

    for (final other in allPosts) {
      if (other.id == closedPost.id) continue;
      if (!_isSeekerVisibleActive(other)) continue;
      if (other.registeredBy?.companyKey?.trim() != companyKey) continue;

      // 서버가 부여한 안정 식별자가 양쪽에 있으면 그것으로 판정 — 좌표/이름
      // 추측(폴백)보다 우선.
      final otherWorkplaceId = other.workplaceId?.trim();
      if (closedWorkplaceId != null &&
          closedWorkplaceId.isNotEmpty &&
          otherWorkplaceId != null &&
          otherWorkplaceId.isNotEmpty) {
        if (closedWorkplaceId == otherWorkplaceId) return true;
        continue;
      }

      final otherCoord = _workplaceCoordinate(other);
      if (closedCoord != null &&
          otherCoord != null &&
          ExposureSlotPolicy.coordinatesMatch(closedCoord, otherCoord)) {
        return true;
      }

      final otherWarehouse = other.warehouseName.trim();
      if (closedWarehouse.isNotEmpty &&
          otherWarehouse.isNotEmpty &&
          closedWarehouse == otherWarehouse) {
        return true;
      }
    }
    return false;
  }

  static bool _isSeekerVisibleActive(CorporateJobPost post) {
    return (post.status == CorporateJobPostStatus.recruiting ||
            post.status == CorporateJobPostStatus.closingSoon) &&
        post.isActiveForSeekers;
  }

  static GeoCoordinate? _workplaceCoordinate(CorporateJobPost post) {
    final stored = JobPostWorkplaceResolver.storedCoordinate(post);
    if (stored != null) return stored;
    return JobPostWorkplaceResolver.coordinateFromSettings(
      post.notificationSettings,
    );
  }
}
