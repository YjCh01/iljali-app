import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_demo.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_entitlement.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  group('CommuteRoute', () {
    test('maxStopsPerRoute is 15', () {
      expect(CommuteRoute.maxStopsPerRoute, 15);
    });

    test('serializes and restores stops with coordinates', () {
      const route = CommuteRoute(
        id: 'r1',
        companyKey: 'ck1',
        routeName: '테스트 셔틀',
        stops: [
          CommuteRouteStop(
            id: 's1',
            label: 'A역',
            coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
          ),
          CommuteRouteStop(
            id: 's2',
            label: 'B역',
            coordinate: GeoCoordinate(latitude: 37.51, longitude: 127.01),
          ),
        ],
        overlayColorHex: '#FFFFFF',
        vehicleGuide: '12가3456',
      );

      final restored = CommuteRoute.fromJson(route.toJson());
      expect(restored.id, 'r1');
      expect(restored.stops.length, 2);
      expect(restored.stops.first.label, 'A역');
      expect(restored.effectivePolylinePoints.length, 2);
      expect(restored.overlayColorHex, '#FFFFFF');
      expect(restored.vehicleGuide, '12가3456');
    });

    test('demo daiso sejong route has 4 stops', () {
      final demo = CommuteRouteDemo.daisoSejongForCompany('corp_alpha');
      expect(demo.id, CommuteRouteDemoIds.daisoSejong);
      expect(demo.stops.length, 4);
      expect(demo.effectivePolylinePoints.length, greaterThanOrEqualTo(2));
      expect(demo.stops.last.label, contains('다이소'));
      expect(demo.stops.first.departureTime, '07:30');
      expect(demo.isFreeShuttle, isTrue);
      expect(demo.boardingNotes, contains('5분 전 대기'));
      expect(demo.arrivalInstructions, isNot(contains('도착을 권장')));
      expect(demo.vehicleGuide, isNotEmpty);
    });

    test('stop photo path serializes', () {
      const stop = CommuteRouteStop(
        id: 's1',
        label: '평택중학교 정문',
        coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
        photoPath: '/tmp/stop.jpg',
      );
      final restored = CommuteRouteStop.fromJson(stop.toJson());
      expect(restored.photoPath, '/tmp/stop.jpg');
    });

    test('stop departure time serializes', () {
      const stop = CommuteRouteStop(
        id: 's1',
        label: 'A역',
        coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
        departureTime: '08:00',
      );
      final restored = CommuteRouteStop.fromJson(stop.toJson());
      expect(restored.departureTime, '08:00');
    });
  });

  group('ShuttleRouteStopPolicy', () {
    const stopA = CommuteRouteStop(
      id: 's1',
      label: 'A역',
      coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
    );
    const stopB = CommuteRouteStop(
      id: 's2',
      label: 'B역',
      coordinate: GeoCoordinate(latitude: 37.51, longitude: 127.01),
    );
    const workplace = CommuteRouteStop(
      id: ShuttleRouteStopPolicy.workplaceStopId,
      label: ShuttleRouteStopPolicy.workplaceLabel,
      coordinate: GeoCoordinate(latitude: 37.6, longitude: 127.1),
    );

    test('maxIntermediateStops is maxStopsPerRoute minus workplace', () {
      expect(ShuttleRouteStopPolicy.maxIntermediateStops, 14);
      expect(
        ShuttleRouteStopPolicy.maxIntermediateStops,
        CommuteRoute.maxStopsPerRoute - 1,
      );
    });

    test('splitRouteStops extracts workplace from any position', () {
      final split = ShuttleRouteStopPolicy.splitRouteStops([
        stopA,
        workplace,
        stopB,
      ]);
      expect(split.intermediate, [stopA, stopB]);
      expect(split.workplace.label, ShuttleRouteStopPolicy.workplaceLabel);
      expect(split.workplace.departureTime, isNull);
    });

    test('splitRouteStops treats last stop as workplace when unmarked', () {
      final split = ShuttleRouteStopPolicy.splitRouteStops([stopA, stopB]);
      expect(split.intermediate, [stopA]);
      expect(split.workplace.coordinate, stopB.coordinate);
      expect(split.workplace.label, ShuttleRouteStopPolicy.workplaceLabel);
    });

    test('splitRouteStops with single legacy stop yields empty intermediate', () {
      final split = ShuttleRouteStopPolicy.splitRouteStops([stopA]);
      expect(split.intermediate, isEmpty);
      expect(split.workplace.coordinate, stopA.coordinate);
    });

    test('mergeStops appends normalized workplace last', () {
      final merged = ShuttleRouteStopPolicy.mergeStops(
        [stopA, stopB],
        workplace.copyWith(label: '다른 이름', departureTime: '09:00'),
      );
      expect(merged.length, 3);
      expect(merged.last.id, ShuttleRouteStopPolicy.workplaceStopId);
      expect(merged.last.label, ShuttleRouteStopPolicy.workplaceLabel);
      expect(merged.last.departureTime, isNull);
    });

    test('isWorkplaceStop matches id or label', () {
      expect(ShuttleRouteStopPolicy.isWorkplaceStop(workplace), isTrue);
      expect(
        ShuttleRouteStopPolicy.isWorkplaceStop(
          stopA.copyWith(label: ShuttleRouteStopPolicy.workplaceLabel),
        ),
        isTrue,
      );
      expect(ShuttleRouteStopPolicy.isWorkplaceStop(stopA), isFalse);
    });

    test('isPushEligibleShuttleStop excludes workplace', () {
      expect(ShuttleRouteStopPolicy.isPushEligibleShuttleStop(stopA), isTrue);
      expect(
        ShuttleRouteStopPolicy.isPushEligibleShuttleStop(workplace),
        isFalse,
      );
      expect(
        ShuttleRouteStopPolicy.pushEligibleStops([stopA, workplace]).toList(),
        [stopA],
      );
    });

    test('filterRegistrableStopIds excludes workplace', () {
      expect(
        ShuttleRouteStopPolicy.filterRegistrableStopIds(
          stopIds: [stopA.id, workplace.id],
          routeStops: [stopA, workplace],
        ),
        [stopA.id],
      );
    });

    test('intermediateCount excludes workplace', () {
      expect(
        ShuttleRouteStopPolicy.intermediateCount([stopA, stopB, workplace]),
        2,
      );
    });
  });

  group('ShuttleRouteEntitlement', () {
    const profile = CorporateMemberProfile(
      companyName: 'A',
      businessRegistrationNumber: '123',
      department: 'HR',
      contactPersonName: 'Kim',
      handlerCode: '0001',
      pushWallet: EmployerPushWallet(packageCredits: 3),
    );

    CorporateJobPost eligiblePost() => CorporateJobPost(
          id: 'p1',
          title: 't',
          warehouseName: '다이소 세종물류센터',
          hourlyWage: '1',
          workSchedule: 's',
          summary: 'x',
          status: CorporateJobPostStatus.recruiting,
          applicantCount: 0,
          postedAt: DateTime(2026, 6, 1),
          registeredBy: profile,
          mapPinDisplayTier: JobMapPinDisplayTier.packageActive,
          commuteRouteId: CommuteRouteDemoIds.daisoSejong,
          hasShuttleRouteOverlay: true,
        );

    test('eligible post shows shuttle overlay', () {
      expect(eligiblePost().showsShuttleRouteOverlay, isTrue);
      expect(ShuttleRouteEntitlement.postEligible(eligiblePost()), isTrue);
    });

    test('route id without paid overlay does not show shuttle', () {
      final post = eligiblePost().copyWith(
        mapPinDisplayTier: JobMapPinDisplayTier.standard,
        hasShuttleRouteOverlay: false,
      );
      expect(post.showsShuttleRouteOverlay, isFalse);
      expect(ShuttleRouteEntitlement.postEligible(post), isFalse);
    });

    test('paid overlay flag enables shuttle overlay', () {
      final post = eligiblePost().copyWith(hasShuttleRouteOverlay: true);
      expect(post.showsShuttleRouteOverlay, isTrue);
      expect(ShuttleRouteEntitlement.postEligible(post), isTrue);
    });

    test('missing route id is not eligible', () {
      final missingRoute = eligiblePost().copyWith(commuteRouteId: '');
      expect(missingRoute.showsShuttleRouteOverlay, isFalse);
    });
  });
}
