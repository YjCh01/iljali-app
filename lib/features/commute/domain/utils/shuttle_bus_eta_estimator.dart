import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_polyline_geometry.dart';

/// 셔틀 버스 → 정류장 도착 예상 시간 (도로 추종 거리 + 평균 시속)
abstract final class ShuttleBusEtaEstimator {
  /// 도심 셔틀 평균 속도 ~28km/h
  static const avgSpeedMetersPerSecond = 28 * 1000 / 3600;

  /// [routeGeometry]와 [stopIndex]가 함께 주어지면 도로 추종 거리로 계산 —
  /// 없으면 직선 거리로 대체(폴리라인이 없는 노선 등).
  static Duration? etaToStop({
    required GeoCoordinate? busPosition,
    required GeoCoordinate stopPosition,
    ShuttleRoutePolylineGeometry? routeGeometry,
    int? stopIndex,
  }) {
    if (busPosition == null) return null;
    final meters = routeGeometry != null && stopIndex != null
        ? routeGeometry.remainingMetersToStop(busPosition, stopIndex)
        : GeoDistance.metersBetween(busPosition, stopPosition);
    if (meters <= 40) return Duration.zero;
    final seconds = (meters / avgSpeedMetersPerSecond).round();
    return Duration(seconds: seconds.clamp(15, 7200));
  }

  static String formatCountdown(Duration duration) {
    if (duration <= Duration.zero) return '곧 도착';
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMin = minutes % 60;
      return '$hours시간 ${remMin}분';
    }
    if (minutes > 0) {
      return '$minutes분 ${seconds.toString().padLeft(2, '0')}초 전';
    }
    return '$seconds초 전';
  }
}
