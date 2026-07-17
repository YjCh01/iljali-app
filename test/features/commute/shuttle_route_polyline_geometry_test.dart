import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_polyline_geometry.dart';

CommuteRouteStop _stop(String id, double lat, double lng) => CommuteRouteStop(
      id: id,
      label: id,
      coordinate: GeoCoordinate(latitude: lat, longitude: lng),
    );

void main() {
  // A(37.500,127.000) 에서 정동쪽으로 간 다음 정북쪽으로 꺾어 B(37.5016,127.002)에
  // 도착하는 ㄱ자 도로 — 두 구간 길이가 비슷하도록 잡아, 모서리가 도로 거리 기준으로는
  // 대략 절반 지점이지만 A-B 직선상에는 전혀 있지 않음을 보인다.
  final stopA = _stop('a', 37.500, 127.000);
  final stopB = _stop('b', 37.5016, 127.002);
  final polyline = [
    const GeoCoordinate(latitude: 37.500, longitude: 127.000), // A
    const GeoCoordinate(latitude: 37.500, longitude: 127.002), // 모서리 (정동쪽)
    const GeoCoordinate(latitude: 37.5016, longitude: 127.002), // B (정북쪽)
  ];

  group('ShuttleRoutePolylineGeometry.build', () {
    test('returns null for too-short input', () {
      expect(
        ShuttleRoutePolylineGeometry.build(points: const [], stops: [stopA, stopB]),
        isNull,
      );
      expect(
        ShuttleRoutePolylineGeometry.build(points: polyline, stops: [stopA]),
        isNull,
      );
    });

    test('builds successfully for a valid L-shaped polyline', () {
      final geometry = ShuttleRoutePolylineGeometry.build(
        points: polyline,
        stops: [stopA, stopB],
      );
      expect(geometry, isNotNull);
    });
  });

  group('ShuttleRoutePolylineGeometry.resolveStopSegment', () {
    late ShuttleRoutePolylineGeometry geometry;

    setUp(() {
      geometry = ShuttleRoutePolylineGeometry.build(
        points: polyline,
        stops: [stopA, stopB],
      )!;
    });

    test('bus at stop A resolves to the start of the segment', () {
      final result = geometry.resolveStopSegment(stopA.coordinate);
      expect(result.segmentIndex, 0);
      expect(result.segmentFraction, closeTo(0.0, 0.01));
    });

    test('bus at stop B resolves to the end of the segment', () {
      final result = geometry.resolveStopSegment(stopB.coordinate);
      expect(result.segmentIndex, 0);
      expect(result.segmentFraction, closeTo(1.0, 0.01));
    });

    test(
        'bus at the road corner is roughly halfway by road distance, '
        'even though it is not halfway on the straight A-B line', () {
      // 모서리(37.500, 127.002)는 A~B 직선에서 한참 벗어나 있음 — 직선 기준이면
      // 이 지점의 "진행률"은 뒤죽박죽이지만, 도로 거리 기준으로는 두 구간의
      // 길이가 거의 같으므로 절반 지점에 가깝다.
      const corner = GeoCoordinate(latitude: 37.500, longitude: 127.002);
      final result = geometry.resolveStopSegment(corner);
      expect(result.segmentIndex, 0);
      expect(result.segmentFraction, closeTo(0.5, 0.05));
    });
  });

  group('ShuttleRoutePolylineGeometry.remainingMetersToStop', () {
    test('decreases as the bus advances along the road', () {
      final geometry = ShuttleRoutePolylineGeometry.build(
        points: polyline,
        stops: [stopA, stopB],
      )!;
      const nearStart = GeoCoordinate(latitude: 37.500, longitude: 127.0005);
      const nearEnd = GeoCoordinate(latitude: 37.5016, longitude: 127.0018);

      final remainingNearStart = geometry.remainingMetersToStop(nearStart, 1);
      final remainingNearEnd = geometry.remainingMetersToStop(nearEnd, 1);
      expect(remainingNearEnd, lessThan(remainingNearStart));
    });

    test('is zero once the bus has passed the target stop', () {
      final geometry = ShuttleRoutePolylineGeometry.build(
        points: polyline,
        stops: [stopA, stopB],
      )!;
      final remaining = geometry.remainingMetersToStop(stopB.coordinate, 1);
      expect(remaining, closeTo(0, 1));
    });
  });
}
