import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';

/// 버스 GPS → 세로 노선 타임라인 상 위치
class ShuttleBusTimelinePosition {
  const ShuttleBusTimelinePosition({
    required this.segmentIndex,
    required this.segmentFraction,
    required this.nearestStopIndex,
  });

  /// 버스가 `segmentIndex` 와 `segmentIndex+1` 정류장 사이에 있음
  final int segmentIndex;
  final double segmentFraction;
  final int nearestStopIndex;

  static ShuttleBusTimelinePosition? resolve({
    required List<CommuteRouteStop> stops,
    required GeoCoordinate? busPosition,
  }) {
    if (busPosition == null || stops.length < 2) return null;

    var bestSegment = 0;
    var bestFraction = 0.0;
    var bestDist = double.infinity;

    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i].coordinate;
      final b = stops[i + 1].coordinate;
      final projection = _projectOnSegment(busPosition, a, b);
      if (projection.distanceMeters < bestDist) {
        bestDist = projection.distanceMeters;
        bestSegment = i;
        bestFraction = projection.fraction;
      }
    }

    var nearest = 0;
    var nearestDist = double.infinity;
    for (var i = 0; i < stops.length; i++) {
      final d = GeoDistance.metersBetween(busPosition, stops[i].coordinate);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = i;
      }
    }

    return ShuttleBusTimelinePosition(
      segmentIndex: bestSegment.clamp(0, stops.length - 2),
      segmentFraction: bestFraction.clamp(0.0, 1.0),
      nearestStopIndex: nearest,
    );
  }

  static List<CommuteRouteStop> orderedStops(CommuteRoute route) {
    final split = ShuttleRouteStopPolicy.splitRouteStops(route.stops);
    return [...split.intermediate, split.workplace];
  }

  static ({double fraction, double distanceMeters}) _projectOnSegment(
    GeoCoordinate point,
    GeoCoordinate a,
    GeoCoordinate b,
  ) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = point.longitude;
    final py = point.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-12) {
      final d = GeoDistance.metersBetween(point, a);
      return (fraction: 0.0, distanceMeters: d);
    }

    var t = ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = GeoCoordinate(
      latitude: ay + dy * t,
      longitude: ax + dx * t,
    );
    final dist = GeoDistance.metersBetween(point, proj);
    return (fraction: t, distanceMeters: dist);
  }

  static String formatScheduleRange(List<CommuteRouteStop> stops) {
    if (stops.isEmpty) return '';
    final first = stops.first.departureTime?.trim();
    final last = stops.last.arrivalTime?.trim() ??
        stops.last.departureTime?.trim();
    if (first != null && first.isNotEmpty && last != null && last.isNotEmpty) {
      return '$first~$last';
    }
    if (first != null && first.isNotEmpty) return first;
    if (last != null && last.isNotEmpty) return last;
    return '';
  }
}
