import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/attendance_geofence_service.dart';

void main() {
  const workplace = GeoCoordinate(latitude: 37.5665, longitude: 126.9780);

  test('within 200m geofence is allowed', () {
    const nearby = GeoCoordinate(latitude: 37.5670, longitude: 126.9780);
    final result = AttendanceGeofenceService.evaluate(
      current: nearby,
      workplace: workplace,
      ignoreRelaxedPlatform: true,
    );
    expect(result.allowed, isTrue);
    expect(result.withinGeofence, isTrue);
    expect(result.distanceMeters, lessThan(200));
  });

  test('outside 200m geofence is blocked', () {
    const far = GeoCoordinate(latitude: 37.5800, longitude: 126.9780);
    final result = AttendanceGeofenceService.evaluate(
      current: far,
      workplace: workplace,
      ignoreRelaxedPlatform: true,
    );
    expect(result.allowed, isFalse);
    expect(result.withinGeofence, isFalse);
    expect(result.distanceMeters, greaterThan(200));
  });

  test('mock location is blocked', () {
    const nearby = GeoCoordinate(latitude: 37.5670, longitude: 126.9780);
    final result = AttendanceGeofenceService.evaluate(
      current: nearby,
      workplace: workplace,
      isMocked: true,
      ignoreRelaxedPlatform: true,
    );
    expect(result.allowed, isFalse);
    expect(result.isMocked, isTrue);
    expect(result.reason, 'mock_location');
  });

  test('missing workplace skips geofence', () {
    const current = GeoCoordinate(latitude: 37.5670, longitude: 126.9780);
    final result = AttendanceGeofenceService.evaluate(
      current: current,
      workplace: null,
    );
    expect(result.allowed, isTrue);
    expect(result.relaxed, isTrue);
  });

  test('radius constant is 200m', () {
    expect(AttendanceGeofenceService.radiusMeters, 200.0);
  });
}
