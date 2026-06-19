import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_entitlement.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 기업 홈 지도 — 구직자와 동일 기준의 셔틀 밀도 오버레이 수집
abstract final class CorporateShuttleDensityLoader {
  static Future<List<CorporateShuttleMapOverlay>> load({
    required CommuteRouteRepository routeRepo,
    required List<CorporateJobPost> posts,
    required List<JobMapPin> pins,
  }) async {
    final routes = await routeRepo.loadAllActive();
    return resolve(routes: routes, posts: posts, pins: pins);
  }

  static List<CorporateShuttleMapOverlay> resolve({
    required List<CommuteRoute> routes,
    required List<CorporateJobPost> posts,
    required List<JobMapPin> pins,
  }) {
    if (routes.isEmpty) return const [];

    final pinByPostId = {for (final pin in pins) pin.post.id: pin};
    final routeIdsOnMap = <String>{};
    final workplaceByRoute = <String, GeoCoordinate>{};

    for (final post in posts) {
      if (!post.isActiveForSeekers) continue;
      if (!ShuttleRouteEntitlement.postEligible(post)) continue;

      for (final routeId in post.effectiveLinkedCommuteRouteIds) {
        routeIdsOnMap.add(routeId);
        final pin = pinByPostId[post.id];
        if (pin != null) {
          workplaceByRoute.putIfAbsent(
            routeId,
            () => GeoCoordinate(
              latitude: pin.latitude,
              longitude: pin.longitude,
            ),
          );
        }
      }
    }

    if (routeIdsOnMap.isEmpty) return const [];

    final overlays = <CorporateShuttleMapOverlay>[];
    for (final route in routes) {
      if (!routeIdsOnMap.contains(route.id)) continue;
      if (!ShuttleRouteVisibility.hasSeekerVisibleStops(route)) continue;

      overlays.add(
        CorporateShuttleMapOverlay(
          route: ShuttleRouteVisibility.forSeekerDisplay(route),
          companyKey: route.companyKey,
          workplace: workplaceByRoute[route.id],
        ),
      );
    }

    return overlays;
  }
}
