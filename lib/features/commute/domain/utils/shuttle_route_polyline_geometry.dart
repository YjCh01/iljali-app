import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// 도로 추종 폴리라인(route.effectivePolylinePoints) 위에 버스 GPS를 맵매칭 —
/// 정류장 직선거리 대신 실제 도로 거리로 구간 진행률·ETA를 계산한다.
///
/// ㄱ자·곡선 도로에서 버스가 대각선으로 가로질러 오는 것처럼 보이는 문제를 막기 위함
/// (직선 거리 기준 계산은 실제 도로 모양과 어긋난다).
class ShuttleRoutePolylineGeometry {
  ShuttleRoutePolylineGeometry._(
    this._points,
    this._cumulativeMeters,
    this._stopCumulativeMeters,
  );

  final List<GeoCoordinate> _points;
  final List<double> _cumulativeMeters;
  final List<double> _stopCumulativeMeters;

  /// [points]는 노선 도로 추종 좌표(또는 정류장 좌표로 대체된 값),
  /// [stops]는 순서대로 정렬된 정류장(경유 + 근무지) 목록.
  /// 폴리라인이 정류장 순서와 어긋나면(역주행 등) null을 반환 — 호출부는 이 경우
  /// 위치 정보 없이 처리(예: 아이콘 미표시)하면 된다.
  static ShuttleRoutePolylineGeometry? build({
    required List<GeoCoordinate> points,
    required List<CommuteRouteStop> stops,
  }) {
    if (points.length < 2 || stops.length < 2) return null;

    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] =
          cumulative[i - 1] + GeoDistance.metersBetween(points[i - 1], points[i]);
    }

    // 정류장은 폴리라인이 만들어진 순서대로 등장하므로, 각 정류장의 가장 가까운
    // 폴리라인 지점을 이전 정류장 지점 이후 구간에서만 순차적으로 탐색한다.
    final stopCumulative = <double>[];
    var searchStart = 0;
    for (final stop in stops) {
      var bestIndex = searchStart;
      var bestDist = double.infinity;
      for (var i = searchStart; i < points.length; i++) {
        final d = GeoDistance.metersBetween(stop.coordinate, points[i]);
        if (d < bestDist) {
          bestDist = d;
          bestIndex = i;
        }
      }
      stopCumulative.add(cumulative[bestIndex]);
      searchStart = bestIndex;
    }

    for (var i = 1; i < stopCumulative.length; i++) {
      if (stopCumulative[i] < stopCumulative[i - 1]) return null;
    }

    return ShuttleRoutePolylineGeometry._(points, cumulative, stopCumulative);
  }

  /// [position]을 폴리라인에 투영했을 때의 누적 도로 거리(m).
  double _projectMeters(GeoCoordinate position) {
    var bestMeters = _cumulativeMeters.first;
    var bestDist = double.infinity;
    for (var i = 0; i < _points.length - 1; i++) {
      final projection = _projectOnSegment(position, _points[i], _points[i + 1]);
      if (projection.distanceMeters < bestDist) {
        bestDist = projection.distanceMeters;
        bestMeters = _cumulativeMeters[i] +
            projection.fraction *
                (_cumulativeMeters[i + 1] - _cumulativeMeters[i]);
      }
    }
    return bestMeters;
  }

  /// 도로 거리 기준 — 버스가 stops[segmentIndex]와 stops[segmentIndex+1] 사이
  /// 어디쯤(0~1) 있는지.
  ({int segmentIndex, double segmentFraction}) resolveStopSegment(
    GeoCoordinate busPosition,
  ) {
    final busMeters = _projectMeters(busPosition);
    final lastIndex = _stopCumulativeMeters.length - 2;
    for (var i = 0; i <= lastIndex; i++) {
      final start = _stopCumulativeMeters[i];
      final end = _stopCumulativeMeters[i + 1];
      if (busMeters <= end || i == lastIndex) {
        final span = end - start;
        final fraction =
            span <= 0 ? 0.0 : ((busMeters - start) / span).clamp(0.0, 1.0);
        return (segmentIndex: i, segmentFraction: fraction);
      }
    }
    return (segmentIndex: 0, segmentFraction: 0.0);
  }

  /// 도로 거리 기준 — 버스 → 특정 정류장(인덱스)까지 잔여 거리(m). 이미 지났으면 0.
  double remainingMetersToStop(GeoCoordinate busPosition, int stopIndex) {
    if (stopIndex < 0 || stopIndex >= _stopCumulativeMeters.length) return 0;
    final busMeters = _projectMeters(busPosition);
    final target = _stopCumulativeMeters[stopIndex];
    return (target - busMeters).clamp(0.0, double.infinity);
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
      return (fraction: 0.0, distanceMeters: GeoDistance.metersBetween(point, a));
    }

    var t = ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final proj = GeoCoordinate(
      latitude: ay + dy * t,
      longitude: ax + dx * t,
    );
    return (fraction: t, distanceMeters: GeoDistance.metersBetween(point, proj));
  }
}
