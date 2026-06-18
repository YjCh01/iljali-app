import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/services/nearest_shuttle_stop_service.dart';

void main() {
  group('NearestShuttleStopService', () {
    final route = CommuteRoute(
      id: 'r1',
      companyKey: 'corp',
      routeName: '테스트 노선',
      stops: const [
        CommuteRouteStop(
          id: 'far',
          label: '먼 정류장',
          coordinate: GeoCoordinate(latitude: 37.60, longitude: 127.10),
          departureTime: '07:00',
        ),
        CommuteRouteStop(
          id: 'near',
          label: '가까운 정류장',
          coordinate: GeoCoordinate(latitude: 37.5135, longitude: 127.1005),
          departureTime: '07:30',
        ),
      ],
    );

    test('returns nearest stop by GPS distance', () {
      final user = GeoCoordinate(latitude: 37.5133, longitude: 127.1002);
      final result = NearestShuttleStopService.findNearest(
        userPosition: user,
        route: route,
      );

      expect(result, isNotNull);
      expect(result!.stop.id, 'near');
      expect(result.distanceMeters, lessThan(500));
      expect(result.etaHintMinutes, greaterThan(0));
    });

    test('returns null when stops lack coordinates', () {
      final emptyRoute = CommuteRoute(
        id: 'r2',
        companyKey: 'corp',
        routeName: '빈 노선',
        stops: const [
          CommuteRouteStop(
            id: 'zero',
            label: '좌표 없음',
            coordinate: GeoCoordinate(latitude: 0, longitude: 0),
          ),
        ],
      );
      final result = NearestShuttleStopService.findNearest(
        userPosition: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
        route: emptyRoute,
      );
      expect(result, isNull);
    });
  });
}
