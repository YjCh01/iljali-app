import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// 셔틀 노선·정류장 구직자 지도 노출 규칙
abstract final class ShuttleRouteVisibility {
  /// 노선 경로(폴리라인) 표시 — 활성화된 정류장 수 기준 (근무지 제외)
  static const polylineMinActivatedStops = 3;

  static int activatedStopCount(CommuteRoute route) =>
      route.stops.where((s) => s.exposureActivated).length;

  static bool showsPolyline(CommuteRoute route) =>
      activatedStopCount(route) >= polylineMinActivatedStops;

  static bool hasSeekerVisibleStops(CommuteRoute route) =>
      route.stops.any((s) => s.exposureActivated);

  /// 구직자 지도 — 활성화된 정류장만, 3곳 미만이면 핀만
  static CommuteRoute forSeekerDisplay(CommuteRoute route) {
    final activeStops =
        route.stops.where((s) => s.exposureActivated).toList(growable: false);
    if (activeStops.isEmpty) return route;

    final showLine = activeStops.length >= polylineMinActivatedStops;
    return route.copyWith(
      stops: activeStops,
      polylinePoints: showLine
          ? activeStops.map((s) => s.coordinate).toList(growable: false)
          : const [],
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
