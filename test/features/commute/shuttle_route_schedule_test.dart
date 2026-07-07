import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_schedule.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';

CommuteRoute _route({
  String firstDeparture = '07:00',
  String workplaceArrival = '08:30',
}) {
  return CommuteRoute(
    id: 'r1',
    companyKey: 'co1',
    routeName: 'A노선',
    stops: ShuttleRouteStopPolicy.mergeStops(
      [
        CommuteRouteStop(
          id: 's1',
          label: '첫 정류장',
          coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
          departureTime: firstDeparture,
        ),
      ],
      CommuteRouteStop(
        id: ShuttleRouteStopPolicy.workplaceStopId,
        label: ShuttleRouteStopPolicy.workplaceLabel,
        coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
        arrivalTime: workplaceArrival,
      ),
    ),
    polylinePoints: const [],
    overlayColorHex: '#E53935',
  );
}

void main() {
  test('validateRequiredTimes passes with first stop and workplace arrival', () {
    expect(ShuttleRouteSchedule.validateRequiredTimes(_route()), isNull);
  });

  test('validateRequiredTimes fails without workplace arrival', () {
    final route = _route(workplaceArrival: '');
    final err = ShuttleRouteSchedule.validateRequiredTimes(route);
    expect(err, contains('근무지 도착'));
  });

  test('seeker tracking window is 30min before first stop to 30min after arrival',
      () {
    final now = DateTime(2026, 7, 6, 6, 29);
    expect(ShuttleRouteSchedule.isWithinSeekerTrackingWindow(_route(), now),
        isFalse);
    final inside = DateTime(2026, 7, 6, 6, 30);
    expect(ShuttleRouteSchedule.isWithinSeekerTrackingWindow(_route(), inside),
        isTrue);
    final after = DateTime(2026, 7, 6, 9, 1);
    expect(ShuttleRouteSchedule.isWithinSeekerTrackingWindow(_route(), after),
        isFalse);
  });

  test('corporate notify window is 15min lead and trail', () {
    final now = DateTime(2026, 7, 6);
    final window = ShuttleRouteSchedule.corporateNotifyWindow(_route(), now)!;
    expect(window.start, DateTime(2026, 7, 6, 6, 45));
    expect(window.end, DateTime(2026, 7, 6, 8, 45));
  });
}
