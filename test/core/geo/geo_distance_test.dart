import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';

void main() {
  group('GeoDistance', () {
    test('returns zero for identical coordinates', () {
      const point = GeoCoordinate(latitude: 37.5, longitude: 127.0);
      expect(GeoDistance.metersBetween(point, point), 0);
    });

    test('calculates approximate distance between two points', () {
      const seoul = GeoCoordinate(latitude: 37.5665, longitude: 126.9780);
      const nearby = GeoCoordinate(latitude: 37.5700, longitude: 126.9780);
      final meters = GeoDistance.metersBetween(seoul, nearby);
      expect(meters, greaterThan(300));
      expect(meters, lessThan(500));
    });

    test('formatDistanceMeters uses meters or kilometers', () {
      expect(GeoDistance.formatDistanceMeters(450), '450m');
      expect(GeoDistance.formatDistanceMeters(1500), '1.5km');
    });
  });
}
