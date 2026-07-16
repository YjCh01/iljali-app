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

  group('time-window validation (workDate + workSchedule)', () {
    const nearby = GeoCoordinate(latitude: 37.5670, longitude: 126.9780);

    test('no schedule info skips time validation entirely', () {
      final result = AttendanceGeofenceService.evaluate(
        current: nearby,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
      );
      expect(result.allowed, isTrue);
    });

    test('blocks check-in well before shift start', () {
      final workDate = DateTime.now().add(const Duration(days: 1));
      final result = AttendanceGeofenceService.evaluate(
        current: nearby,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
        workDate: workDate,
        workSchedule: '09:00-18:00',
      );
      expect(result.allowed, isFalse);
      expect(result.reason, 'too_early');
      expect(result.userMessage, contains('아직'));
    });

    test('allows check-in within the 30-minute early window', () {
      final now = DateTime.now();
      final workDate = DateTime(now.year, now.month, now.day);
      final startClock = now.add(const Duration(minutes: 20));
      final schedule =
          '${startClock.hour.toString().padLeft(2, '0')}:${startClock.minute.toString().padLeft(2, '0')}'
          '-23:59';
      final result = AttendanceGeofenceService.evaluate(
        current: nearby,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
        workDate: workDate,
        workSchedule: schedule,
      );
      expect(result.allowed, isTrue);
    });

    test('blocks check-in after the grace window past shift end', () {
      final workDate = DateTime.now().subtract(const Duration(days: 2));
      final result = AttendanceGeofenceService.evaluate(
        current: nearby,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
        workDate: workDate,
        workSchedule: '09:00-18:00',
      );
      expect(result.allowed, isFalse);
      expect(result.reason, 'too_late');
      expect(result.userMessage, contains('지났습니다'));
    });

    test('time check takes priority over geofence distance', () {
      const far = GeoCoordinate(latitude: 37.5800, longitude: 126.9780);
      final workDate = DateTime.now().add(const Duration(days: 1));
      final result = AttendanceGeofenceService.evaluate(
        current: far,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
        workDate: workDate,
        workSchedule: '09:00-18:00',
      );
      expect(result.reason, 'too_early');
      expect(result.distanceMeters, isNull);
    });
  });
}
