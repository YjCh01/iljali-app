import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';

void main() {
  test('travelPath orders stops then workplace', () {
    const route = ClosedGhostRoute(
      id: 'r1',
      workplaceLatitude: 37.5,
      workplaceLongitude: 127.0,
      stops: [
        GeoCoordinate(latitude: 37.51, longitude: 127.01),
        GeoCoordinate(latitude: 37.52, longitude: 127.02),
      ],
    );
    expect(route.travelPath.length, 3);
    expect(route.travelPath.last.latitude, 37.5);
  });
}
