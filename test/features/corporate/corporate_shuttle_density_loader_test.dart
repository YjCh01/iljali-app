import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/services/corporate_shuttle_density_loader.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

CommuteRoute _route({
  required String id,
  required String companyKey,
  bool activated = true,
}) {
  return CommuteRoute(
    id: id,
    companyKey: companyKey,
    routeName: '노선 $id',
    stops: [
      CommuteRouteStop(
        id: 's1',
        label: 'A',
        coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
        exposureActivated: activated,
      ),
      CommuteRouteStop(
        id: 's2',
        label: 'B',
        coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
        exposureActivated: activated,
      ),
    ],
  );
}

CorporateJobPost _post({
  required String id,
  required String routeId,
  required String companyBrn,
}) {
  return CorporateJobPost(
    id: id,
    title: '공고 $id',
    warehouseName: '센터',
    hourlyWage: '12,000원',
    workSchedule: '주5',
    summary: '요약',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 0,
    postedAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(days: 30)),
    commuteRouteId: routeId,
    hasShuttleRouteOverlay: true,
    registeredBy: CorporateMemberProfile(
      companyName: '회사',
      businessRegistrationNumber: companyBrn,
      department: 'HR',
      contactPersonName: 'Kim',
      handlerCode: '1001',
    ),
  );
}

JobMapPin _pin(CorporateJobPost post) {
  return JobMapPin(
    post: post,
    latitude: 37.52,
    longitude: 127.02,
    companyName: '회사',
    displayTier: JobMapPinDisplayTier.standard,
  );
}

void main() {
  group('CorporateShuttleDensityLoader', () {
    test('includes seeker-visible routes linked to overlay posts', () {
      const route = CommuteRoute(
        id: 'route-a',
        companyKey: '1111111111',
        routeName: 'A노선',
        stops: [
          CommuteRouteStop(
            id: 's1',
            label: 'A',
            coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
            exposureActivated: true,
          ),
        ],
      );
      final post = _post(
        id: 'p1',
        routeId: 'route-a',
        companyBrn: '111-11-11111',
      );

      final overlays = CorporateShuttleDensityLoader.resolve(
        routes: [route],
        posts: [post],
        pins: [_pin(post)],
      );

      expect(overlays, hasLength(1));
      expect(overlays.first.route.id, 'route-a');
      expect(overlays.first.companyKey, '1111111111');
      expect(overlays.first.workplace?.latitude, 37.52);
    });

    test('skips routes without activated stops', () {
      final overlays = CorporateShuttleDensityLoader.resolve(
        routes: [_route(id: 'r1', companyKey: '2222222222', activated: false)],
        posts: [
          _post(id: 'p1', routeId: 'r1', companyBrn: '2222222222'),
        ],
        pins: [],
      );
      expect(overlays, isEmpty);
    });

    test('skips posts without shuttle overlay flag', () {
      final post = _post(
        id: 'p1',
        routeId: 'r1',
        companyBrn: '3333333333',
      ).copyWith(hasShuttleRouteOverlay: false);

      final overlays = CorporateShuttleDensityLoader.resolve(
        routes: [_route(id: 'r1', companyKey: '3333333333')],
        posts: [post],
        pins: [_pin(post)],
      );
      expect(overlays, isEmpty);
    });
  });
}
