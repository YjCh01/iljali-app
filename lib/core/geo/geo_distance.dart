import 'dart:math' as math;

import 'package:map/core/geo/geo_coordinate.dart';

/// 두 좌표 간 거리(미터) — Haversine
abstract final class GeoDistance {
  static const earthRadiusMeters = 6371000.0;

  static double metersBetween(GeoCoordinate from, GeoCoordinate to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static String formatDistanceMeters(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
