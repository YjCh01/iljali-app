import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_target_resolver.dart';

CorporateJobPost _post({JobPostNotificationSettings? settings, String? routeId}) {
  return CorporateJobPost(
    id: 'p1',
    title: 'test',
    warehouseName: '매장',
    hourlyWage: '10,320원',
    workSchedule: '09:00~18:00',
    summary: 'test',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 0,
    postedAt: DateTime(2026, 5, 28),
    notificationSettings: settings,
    commuteRouteId: routeId,
  );
}

void main() {
  test('includes workplace and notification pin targets', () {
    final targets = PushDispatchTargetResolver.resolveSync(
      post: _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            PushNotificationBasePoint(
              id: 'w',
              coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
              addressLabel: '본사',
              radiusTier: PushRadiusTier.standardFree1km,
            ),
            PushNotificationBasePoint(
              id: 'p1',
              coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
              addressLabel: '역 앞',
              radiusTier: PushRadiusTier.standard1km,
            ),
          ],
        ),
      ),
    );

    expect(targets.length, 2);
    expect(targets[0].kind, PushDispatchTargetKind.workplace);
    expect(targets[1].kind, PushDispatchTargetKind.notificationPin);
  });

  test('includes shuttle stop targets when route provided', () {
    final route = CommuteRoute(
      id: 'r1',
      companyKey: 'c1',
      routeName: 'A노선',
      stops: const [
        CommuteRouteStop(
          id: 's1',
          label: '정류장1',
          coordinate: GeoCoordinate(latitude: 37.52, longitude: 127.02),
        ),
      ],
    );

    final targets = PushDispatchTargetResolver.resolve(
      post: _post(routeId: 'r1'),
      commuteRoute: route,
    );

    expect(targets.length, 1);
    expect(targets.single.kind, PushDispatchTargetKind.shuttleStop);
    expect(targets.single.title, '정류장1');
  });

  test('excludes shuttle workplace stop from push targets', () {
    final route = CommuteRoute(
      id: 'r1',
      companyKey: 'c1',
      routeName: 'A노선',
      stops: const [
        CommuteRouteStop(
          id: 's1',
          label: '정류장1',
          coordinate: GeoCoordinate(latitude: 37.52, longitude: 127.02),
          exposureActivated: true,
        ),
        CommuteRouteStop(
          id: ShuttleRouteStopPolicy.workplaceStopId,
          label: ShuttleRouteStopPolicy.workplaceLabel,
          coordinate: GeoCoordinate(latitude: 37.53, longitude: 127.03),
          exposureActivated: true,
        ),
      ],
    );

    final targets = PushDispatchTargetResolver.resolve(
      post: _post(routeId: 'r1'),
      commuteRoute: route,
    );

    expect(targets.length, 1);
    expect(targets.single.shuttleStopId, 's1');
    expect(targets.single.title, '정류장1');
  });
}
