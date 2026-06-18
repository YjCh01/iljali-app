import 'dart:math' as math;

import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';

/// 셔틀 노선 경로 — 정류장 + 근무지 핀 연결
abstract final class CommuteRoutePolyline {
  static const _workplaceMergeMeters = 40.0;

  /// 정류장 좌표 + (필요 시) 근무지 핀까지 이어지는 경로
  static List<GeoCoordinate> pathIncludingWorkplace({
    required CommuteRoute route,
    GeoCoordinate? workplace,
  }) {
    final points = List<GeoCoordinate>.from(route.effectivePolylinePoints);
    if (points.isEmpty) return points;

    final routeEndsAtWorkplace = route.stops.isNotEmpty &&
        ShuttleRouteStopPolicy.isWorkplaceStop(route.stops.last);

    if (workplace == null) {
      return points;
    }

    final anchor = points.last;
    if (_distanceMeters(anchor, workplace) <= _workplaceMergeMeters) {
      return points;
    }

    if (routeEndsAtWorkplace) {
      return [...points.sublist(0, points.length - 1), workplace];
    }

    return [...points, workplace];
  }

  static double _distanceMeters(GeoCoordinate a, GeoCoordinate b) {
    const metersPerDegLat = 111320.0;
    final meanLat = (a.latitude + b.latitude) / 2;
    final dx = (b.longitude - a.longitude) *
        metersPerDegLat *
        math.cos(meanLat * math.pi / 180);
    final dy = (b.latitude - a.latitude) * metersPerDegLat;
    return math.sqrt(dx * dx + dy * dy);
  }
}
