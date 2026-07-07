import 'package:map/core/map/ghost_route_overlay_factory.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';

/// 유령노선도 — 웹 점선 + 작은 번호 마커
abstract final class GhostRouteWebOverlayBuilder {
  static ({List<NaverMapWebMarkerSpec> markers, List<NaverMapWebPolylineSpec> polylines})
      fromRoutes(List<ClosedGhostRoute> routes) {
    final markers = <NaverMapWebMarkerSpec>[];
    final polylines = <NaverMapWebPolylineSpec>[];
    final ghostHex = NaverMapWebColors.hex(MapPinColors.ghost);

    for (final route in routes) {
      final built = _fromRoute(route, ghostHex: ghostHex);
      markers.addAll(built.markers);
      polylines.addAll(built.polylines);
    }
    return (markers: markers, polylines: polylines);
  }

  static ({List<NaverMapWebMarkerSpec> markers, List<NaverMapWebPolylineSpec> polylines})
      _fromRoute(
    ClosedGhostRoute route, {
    required String ghostHex,
  }) {
    final markers = <NaverMapWebMarkerSpec>[];
    final polylines = <NaverMapWebPolylineSpec>[];
    final hasWorkplace = route.workplaceLatitude.abs() > 1e-6 ||
        route.workplaceLongitude.abs() > 1e-6;
    final path = hasWorkplace ? route.travelPath : route.stops;

    if (hasWorkplace && path.length >= 2) {
      polylines.add(
        NaverMapWebPolylineSpec(
          id: 'ghost_route_${route.id}',
          points: [
            for (final c in path)
              (latitude: c.latitude, longitude: c.longitude),
          ],
          colorHex: ghostHex,
          strokeWeight: 4,
          dashed: true,
        ),
      );
    }

    for (var i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];
      markers.add(
        NaverMapWebMarkerSpec(
          id: 'ghost_route_stop_${route.id}_$i',
          latitude: stop.latitude,
          longitude: stop.longitude,
          colorHex: ghostHex,
          label: '${i + 1}',
          kind: MapPinMarkerKind.busStop,
          size: 22,
          height: 22,
        ),
      );
    }

    if (hasWorkplace) {
      markers.add(
        NaverMapWebMarkerSpec(
          id: GhostRouteOverlayFactory.workplaceMarkerIdFor(route.id),
          latitude: route.workplaceLatitude,
          longitude: route.workplaceLongitude,
          colorHex: ghostHex,
          label: '근무지',
          kind: MapPinMarkerKind.workplace,
          size: 24,
          height: 24,
        ),
      );
    }

    return (markers: markers, polylines: polylines);
  }
}
