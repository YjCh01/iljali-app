import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 마감유령핀 → [JobMapPin] 변환
abstract final class ClosedGhostJobMapPinFactory {
  static const message = '마감된 공고입니다.';

  static bool qualifiesExpiredFreePost(CorporateJobPost post) {
    if (post.isActiveForSeekers) return false;
    if (post.effectiveMapPinTier != JobMapPinDisplayTier.standard) {
      return false;
    }
    return post.status == CorporateJobPostStatus.closed || post.isExpired;
  }

  static JobMapPin fromPost(CorporateJobPost post, GeoCoordinate coordinate) {
    return JobMapPin(
      post: post,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      companyName: post.registeredBy?.companyName ?? post.warehouseName,
      displayTier: JobMapPinDisplayTier.closedGhost,
      kind: JobMapPinKind.closedGhost,
      ghostPinId: 'post_${post.id}',
    );
  }

  static JobMapPin fromAdminPin(ClosedGhostPin pin, {CorporateJobPost? sourcePost}) {
    final post = sourcePost ?? _placeholderPost(pin);
    return JobMapPin(
      post: post,
      latitude: pin.latitude,
      longitude: pin.longitude,
      companyName: pin.label.isNotEmpty
          ? pin.label
          : (sourcePost?.registeredBy?.companyName ??
              sourcePost?.warehouseName ??
              '마감유령핀'),
      displayTier: JobMapPinDisplayTier.closedGhost,
      kind: JobMapPinKind.closedGhost,
      ghostPinId: pin.id,
    );
  }

  static CorporateJobPost _placeholderPost(ClosedGhostPin pin) {
    final now = DateTime.now();
    return CorporateJobPost(
      id: pin.sourcePostId ?? pin.id,
      title: pin.label.isNotEmpty ? pin.label : '마감된 공고',
      warehouseName: pin.label,
      hourlyWage: '',
      workSchedule: '',
      summary: '',
      jobDescription: '',
      status: CorporateJobPostStatus.closed,
      applicantCount: 0,
      postedAt: now.subtract(const Duration(days: 2)),
      expiresAt: JobPostValidity.expiresAtFromRegistration(
        now.subtract(const Duration(days: 2)),
      ),
      workerCategory: WorkerCategory.daily,
    );
  }
}
