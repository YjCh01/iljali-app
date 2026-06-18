import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/commute_route_polyline.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';

void main() {
  test('pathIncludingWorkplace appends workplace when far from last stop', () {
    const route = CommuteRoute(
      id: 'r1',
      companyKey: 'c1',
      routeName: '셔틀',
      stops: [
        CommuteRouteStop(
          id: 's1',
          label: 'A역',
          coordinate: GeoCoordinate(latitude: 37.50, longitude: 127.00),
          departureTime: '07:30',
        ),
        CommuteRouteStop(
          id: 's2',
          label: 'B역',
          coordinate: GeoCoordinate(latitude: 37.51, longitude: 127.01),
        ),
      ],
    );
    const workplace = GeoCoordinate(latitude: 37.60, longitude: 127.10);

    final path = CommuteRoutePolyline.pathIncludingWorkplace(
      route: route,
      workplace: workplace,
    );

    expect(path.length, 3);
    expect(path.last, workplace);
  });

  test('pathIncludingWorkplace does not duplicate stored workplace stop', () {
    const route = CommuteRoute(
      id: 'r2',
      companyKey: 'c1',
      routeName: '셔틀',
      stops: [
        CommuteRouteStop(
          id: 's1',
          label: 'A역',
          coordinate: GeoCoordinate(latitude: 37.50, longitude: 127.00),
        ),
        CommuteRouteStop(
          id: ShuttleRouteStopPolicy.workplaceStopId,
          label: ShuttleRouteStopPolicy.workplaceLabel,
          coordinate: GeoCoordinate(latitude: 37.60, longitude: 127.10),
        ),
      ],
    );
    const workplace = GeoCoordinate(latitude: 37.60, longitude: 127.10);

    final path = CommuteRoutePolyline.pathIncludingWorkplace(
      route: route,
      workplace: workplace,
    );

    expect(path.length, 2);
    expect(path.last, workplace);
  });
}
