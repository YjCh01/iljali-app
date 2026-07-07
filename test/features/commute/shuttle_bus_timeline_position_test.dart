import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_bus_timeline_position.dart';

void main() {
  const stops = [
    CommuteRouteStop(
      id: 's1',
      label: '정자역',
      coordinate: GeoCoordinate(latitude: 37.37, longitude: 127.11),
      departureTime: '07:00',
    ),
    CommuteRouteStop(
      id: 's2',
      label: '판교역',
      coordinate: GeoCoordinate(latitude: 37.39, longitude: 127.11),
      departureTime: '07:15',
    ),
    CommuteRouteStop(
      id: 's3',
      label: '근무지',
      coordinate: GeoCoordinate(latitude: 37.41, longitude: 127.11),
      arrivalTime: '08:00',
    ),
  ];

  const route = CommuteRoute(
    id: 'r1',
    companyKey: 'ck1',
    routeName: '5400',
    stops: stops,
    overlayColorHex: '#C49A6C',
  );

  group('ShuttleBusTimelinePosition', () {
    test('orderedStops puts workplace last', () {
      final ordered = ShuttleBusTimelinePosition.orderedStops(route);
      expect(ordered.length, 3);
      expect(ordered.last.label, '근무지');
    });

    test('formatScheduleRange uses first departure and workplace arrival', () {
      final ordered = ShuttleBusTimelinePosition.orderedStops(route);
      expect(
        ShuttleBusTimelinePosition.formatScheduleRange(ordered),
        '07:00~08:00',
      );
    });

    test('resolve places bus on segment between stops', () {
      final bus = const GeoCoordinate(latitude: 37.38, longitude: 127.11);
      final pos = ShuttleBusTimelinePosition.resolve(
        stops: stops,
        busPosition: bus,
      );
      expect(pos, isNotNull);
      expect(pos!.segmentIndex, 0);
      expect(pos.segmentFraction, greaterThan(0.4));
      expect(pos.segmentFraction, lessThan(0.6));
      expect(pos.nearestStopIndex, anyOf(0, 1));
    });

    test('resolve returns null without bus position', () {
      expect(
        ShuttleBusTimelinePosition.resolve(stops: stops, busPosition: null),
        isNull,
      );
    });
  });
}
