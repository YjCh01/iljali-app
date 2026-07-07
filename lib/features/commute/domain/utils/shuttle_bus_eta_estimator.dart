import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';

/// 셔틀 버스 → 정류장 도착 예상 시간 (직선 거리 + 평균 시속)
abstract final class ShuttleBusEtaEstimator {
  /// 도심 셔틀 평균 속도 ~28km/h
  static const avgSpeedMetersPerSecond = 28 * 1000 / 3600;

  static Duration? etaToStop({
    required GeoCoordinate? busPosition,
    required GeoCoordinate stopPosition,
  }) {
    if (busPosition == null) return null;
    final meters = GeoDistance.metersBetween(busPosition, stopPosition);
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
