import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

/// 구직자 지도 — 노출 중인 일자리 알림핀 (근무지와 별도 좌표)
class JobRecruitmentMapPin {
  const JobRecruitmentMapPin({
    required this.post,
    required this.point,
    required this.workplace,
    required this.index,
  });

  final CorporateJobPost post;
  final PushNotificationBasePoint point;
  final GeoCoordinate workplace;
  final int index;

  GeoCoordinate get coordinate => point.coordinate;
}

abstract final class JobRecruitmentMapPinFactory {
  static List<JobRecruitmentMapPin> fromPosts(Iterable<CorporateJobPost> posts) {
    final pins = <JobRecruitmentMapPin>[];
    for (final post in posts) {
      pins.addAll(fromPost(post));
    }
    return pins;
  }

  static List<JobRecruitmentMapPin> fromPost(CorporateJobPost post) {
    final settings = post.notificationSettings;
    if (settings == null || settings.basePoints.length < 2) {
      return const [];
    }
    final workplace = JobPostWorkplaceResolver.resolveCoordinate(post);
    final result = <JobRecruitmentMapPin>[];
    for (var i = 1; i < settings.basePoints.length; i++) {
      if (!PushWalletCreditPolicy.isRecruitmentZoneIndex(i)) continue;
      final point = settings.basePoints[i];
      if (!point.isExposureLocked) continue;
      result.add(
        JobRecruitmentMapPin(
          post: post,
          point: point,
          workplace: workplace,
          index: i,
        ),
      );
    }
    return result;
  }
}
