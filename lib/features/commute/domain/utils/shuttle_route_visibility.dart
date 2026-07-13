import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// 셔틀 노선·정류장 구직자 지도 노출 규칙
abstract final class ShuttleRouteVisibility {
  /// 노선 경로(폴리라인) 표시 — 활성화된 정류장 수 기준 (근무지 제외)
  static const polylineMinActivatedStops = 3;

  /// 정류장 직선보다 밀집된 도로 추종 경로로 간주하는 최소 배수
  static const roadGeometryMinPointFactor = 2;

  static int activatedStopCount(CommuteRoute route) =>
      route.stops.where((s) => s.exposureActivated).length;

  static bool showsPolyline(CommuteRoute route) =>
      activatedStopCount(route) >= polylineMinActivatedStops;

  static bool hasSeekerVisibleStops(CommuteRoute route) =>
      route.stops.any((s) => s.exposureActivated);

  /// 저장된 도로 추종 polyline을 정류장 직선으로 덮어쓰지 않음
  static bool hasRoadFollowingPolyline(CommuteRoute route) {
    final points = route.polylinePoints;
    if (points.length < 2) return false;
    final stopCount = route.stops.length;
    if (stopCount < 2) return points.length >= 2;
    return points.length >= stopCount * roadGeometryMinPointFactor ||
        points.length > stopCount;
  }

  /// 구직자 지도 — 활성화된 정류장만, 3곳 미만이면 핀만
  static CommuteRoute forSeekerDisplay(CommuteRoute route) {
    final activeStops =
        route.stops.where((s) => s.exposureActivated).toList(growable: false);
    if (activeStops.isEmpty) return route;

    final showLine = activeStops.length >= polylineMinActivatedStops;
    if (!showLine) {
      return route.copyWith(
        stops: activeStops,
        polylinePoints: const [],
      );
    }

    // 서버 densify된 도로 경로 보존 (정류장 좌표로 재생성하지 않음)
    if (hasRoadFollowingPolyline(route)) {
      return route.copyWith(
        stops: activeStops,
        polylinePoints: route.polylinePoints,
      );
    }

    return route.copyWith(
      stops: activeStops,
      polylinePoints:
          activeStops.map((s) => s.coordinate).toList(growable: false),
    );
  }

  static List<CommuteRouteStop> previewPolylineStops(
    List<CommuteRouteStop> stops,
  ) {
    final active = stops.where((s) => s.exposureActivated).toList();
    if (active.length >= polylineMinActivatedStops) return active;
    return const [];
  }
}
