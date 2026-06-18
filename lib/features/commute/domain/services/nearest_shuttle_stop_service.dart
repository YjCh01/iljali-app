import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// GPS + 노선 → 가장 가까운 정류장
class NearestShuttleStopResult {
  const NearestShuttleStopResult({
    required this.stop,
    required this.distanceMeters,
    required this.etaHintMinutes,
  });

  final CommuteRouteStop stop;
  final double distanceMeters;
  final int etaHintMinutes;
}

abstract final class NearestShuttleStopService {
  /// 도보 4km/h 가정 — ETA 힌트(분)
  static const _walkSpeedKmh = 4.0;

  static NearestShuttleStopResult? findNearest({
    required GeoCoordinate userPosition,
    required CommuteRoute route,
  }) {
    if (route.stops.isEmpty) return null;

    CommuteRouteStop? nearest;
    double minDistance = double.infinity;

    for (final stop in route.stops) {
      if (stop.coordinate.latitude == 0 && stop.coordinate.longitude == 0) {
        continue;
      }
      final d = GeoDistance.metersBetween(userPosition, stop.coordinate);
      if (d < minDistance) {
        minDistance = d;
        nearest = stop;
      }
    }

    if (nearest == null) return null;

    final etaMinutes = (minDistance / 1000 / _walkSpeedKmh * 60).ceil().clamp(1, 120);

    return NearestShuttleStopResult(
      stop: nearest,
      distanceMeters: minDistance,
      etaHintMinutes: etaMinutes,
    );
  }
}
