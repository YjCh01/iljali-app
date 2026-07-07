import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_source.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// 토스 PG 전환 등 프로모션 종료 시 promo 활성화만 회수
class PromoExposureCleanupService {
  PromoExposureCleanupService({
    CorporateJobPostLocalDataSource? jobPostDataSource,
  }) : _jobPostDataSource =
            jobPostDataSource ?? const CorporateJobPostLocalDataSourceImpl();

  final CorporateJobPostLocalDataSource _jobPostDataSource;

  Future<bool> clearPromoActivationsIfNeeded({
    required String companyKey,
  }) async {
    if (companyKey.trim().isEmpty) return false;
    if (await FreeExposureLaunchPolicy.isActive()) return false;

    var changed = false;

    final posts =
        await _jobPostDataSource.fetchJobPostsForCompany(companyKey.trim());
    for (final post in posts) {
      final cleared = _clearPromoFromPost(post);
      if (cleared != null) {
        await _jobPostDataSource.updateJobPost(
          cleared,
          ownerCompanyKey: companyKey,
        );
        changed = true;
      }
    }

    final routeRepo = await CommuteRouteRepository.create();
    final routes = await routeRepo.loadForCompany(companyKey.trim());
    for (final route in routes) {
      final cleared = _clearPromoFromRoute(route);
      if (cleared != null) {
        await routeRepo.upsert(cleared);
        changed = true;
      }
    }

    return changed;
  }

  CorporateJobPost? _clearPromoFromPost(CorporateJobPost post) {
    var updated = post;
    var touched = false;

    final settings = post.notificationSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      final points = <PushNotificationBasePoint>[];
      for (final point in settings.basePoints) {
        if (point.exposureActivationSource == ExposureActivationSource.promo &&
            point.exposureActivated) {
          points.add(
            point.copyWith(
              exposureActivated: false,
              clearActivationCoordinate: true,
              clearExposurePaidAt: true,
              clearExposureActivationSource: true,
            ),
          );
          touched = true;
        } else {
          points.add(point);
        }
      }
      if (touched) {
        updated = updated.copyWith(
          notificationSettings: settings.copyWith(basePoints: points),
        );
      }
    }

    if (post.shuttleOverlayActivationSource == ExposureActivationSource.promo &&
        post.hasShuttleRouteOverlay) {
      updated = updated.copyWith(
        hasShuttleRouteOverlay: false,
        clearShuttleOverlayActivationSource: true,
      );
      touched = true;
    }

    return touched ? updated : null;
  }

  CommuteRoute? _clearPromoFromRoute(CommuteRoute route) {
    var touched = false;
    final stops = <CommuteRouteStop>[];
    for (final stop in route.stops) {
      if (stop.exposureActivationSource == ExposureActivationSource.promo &&
          stop.exposureActivated) {
        stops.add(
          stop.copyWith(
            exposureActivated: false,
            clearExposurePaidAt: true,
            clearExposureActivationSource: true,
          ),
        );
        touched = true;
      } else {
        stops.add(stop);
      }
    }
    return touched ? route.copyWith(stops: stops) : null;
  }
}
