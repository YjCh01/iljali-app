import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/commute_route_polyline.dart';
import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';

/// 셔틀 노선 → 웹 지도 마커·폴리라인
abstract final class ShuttleMapWebOverlayBuilder {
  static ({List<NaverMapWebMarkerSpec> markers, List<NaverMapWebPolylineSpec> polylines})
      fromRoute(
    CommuteRoute route, {
    GeoCoordinate? workplace,
    void Function(String markerId)? onStopMarkerId,
    bool showStopCaptions = true,
  }) {
    final colorHex = _routeColorHex(route.overlayColorHex);
    final path = CommuteRoutePolyline.pathIncludingWorkplace(
      route: route,
      workplace: workplace,
    );

    final polylines = path.length >= 2
        ? [
            NaverMapWebPolylineSpec(
              id: 'shuttle_path_${route.id}',
              points: [
                for (final c in path)
                  (latitude: c.latitude, longitude: c.longitude),
              ],
              colorHex: colorHex,
              strokeWeight: 5,
              dashed: true,
            ),
          ]
        : <NaverMapWebPolylineSpec>[];

    final markers = <NaverMapWebMarkerSpec>[];
    for (final stop in route.stops) {
      markers.add(
        NaverMapWebMarkerSpec(
          id: 'shuttle_stop_${route.id}_${stop.id}',
          latitude: stop.coordinate.latitude,
          longitude: stop.coordinate.longitude,
          colorHex: colorHex,
          label: showStopCaptions ? stop.label.substring(0, 1) : '•',
          size: 14,
        ),
      );
      if (showStopCaptions && stop.label.isNotEmpty) {
        // caption via label in marker HTML — full label in title attribute handled in web layer
      }
    }

    if (workplace != null) {
      markers.add(
        NaverMapWebMarkerSpec(
          id: 'shuttle_workplace_${route.id}',
          latitude: workplace.latitude,
          longitude: workplace.longitude,
          colorHex: '#5E35B1',
          label: '근',
          size: 16,
        ),
      );
    }

    return (markers: markers, polylines: polylines);
  }

  static ({List<NaverMapWebMarkerSpec> markers, List<NaverMapWebPolylineSpec> polylines})
      fromShuttleOverlays(
    List<CorporateShuttleMapOverlay> overlays, {
    bool showStopCaptions = false,
  }) {
    final markers = <NaverMapWebMarkerSpec>[];
    final polylines = <NaverMapWebPolylineSpec>[];

    for (final entry in overlays) {
      final built = fromRoute(
        entry.route,
        workplace: entry.workplace,
        showStopCaptions: showStopCaptions,
      );
      markers.addAll(built.markers);
      polylines.addAll(built.polylines);
    }

    return (markers: markers, polylines: polylines);
  }

  static String _routeColorHex(String? raw) {
    if (raw == null || raw.isEmpty) return '#7C5CFC';
    var hex = raw.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) return '#$hex';
    return '#7C5CFC';
  }
}
