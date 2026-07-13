import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';

CommuteRouteStop _stop(
  String id, {
  required double lat,
  required double lng,
  bool activated = true,
}) {
  return CommuteRouteStop(
    id: id,
    label: id,
    coordinate: GeoCoordinate(latitude: lat, longitude: lng),
    exposureActivated: activated,
  );
}

void main() {
  group('ShuttleRouteVisibility.forSeekerDisplay', () {
    test('preserves densified road polyline when enough stops are active', () {
      final road = List<GeoCoordinate>.generate(
        12,
        (i) => GeoCoordinate(
          latitude: 37.5 + i * 0.001,
          longitude: 127.0 + i * 0.001,
        ),
      );
      final route = CommuteRoute(
        id: 'r1',
        companyKey: 'ck',
        routeName: '1호차',
        stops: [
          _stop('a', lat: 37.5, lng: 127.0),
          _stop('b', lat: 37.51, lng: 127.01),
          _stop('c', lat: 37.52, lng: 127.02),
        ],
        polylinePoints: road,
      );

      final display = ShuttleRouteVisibility.forSeekerDisplay(route);
      expect(display.stops.length, 3);
      expect(display.polylinePoints.length, 12);
      expect(
        display.polylinePoints.first.latitude,
        road.first.latitude,
      );
    });

    test('clears polyline when fewer than 3 activated stops', () {
      final road = List<GeoCoordinate>.generate(
        8,
        (i) => GeoCoordinate(
          latitude: 37.5 + i * 0.001,
          longitude: 127.0 + i * 0.001,
        ),
      );
      final route = CommuteRoute(
        id: 'r1',
        companyKey: 'ck',
        routeName: '1호차',
        stops: [
          _stop('a', lat: 37.5, lng: 127.0, activated: true),
          _stop('b', lat: 37.51, lng: 127.01, activated: true),
          _stop('c', lat: 37.52, lng: 127.02, activated: false),
        ],
        polylinePoints: road,
      );

      final display = ShuttleRouteVisibility.forSeekerDisplay(route);
      expect(display.stops.length, 2);
      expect(display.polylinePoints, isEmpty);
    });

    test('falls back to stop coords when polyline is not densified', () {
      final route = CommuteRoute(
        id: 'r1',
        companyKey: 'ck',
        routeName: '1호차',
        stops: [
          _stop('a', lat: 37.5, lng: 127.0),
          _stop('b', lat: 37.51, lng: 127.01),
          _stop('c', lat: 37.52, lng: 127.02),
        ],
        polylinePoints: const [],
      );

      final display = ShuttleRouteVisibility.forSeekerDisplay(route);
      expect(display.polylinePoints.length, 3);
      expect(display.polylinePoints[1].latitude, 37.51);
    });
  });

  group('hasRoadFollowingPolyline', () {
    test('true when points denser than stops', () {
      final route = CommuteRoute(
        id: 'r1',
        companyKey: 'ck',
        routeName: '1호차',
        stops: [
          _stop('a', lat: 37.5, lng: 127.0),
          _stop('b', lat: 37.51, lng: 127.01),
        ],
        polylinePoints: [
          const GeoCoordinate(latitude: 37.5, longitude: 127.0),
          const GeoCoordinate(latitude: 37.505, longitude: 127.005),
          const GeoCoordinate(latitude: 37.51, longitude: 127.01),
        ],
      );
      expect(ShuttleRouteVisibility.hasRoadFollowingPolyline(route), isTrue);
    });
  });
}
