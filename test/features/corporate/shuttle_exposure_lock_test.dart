import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';

CorporateJobPost _post({
  bool overlay = true,
  Map<String, List<String>> registered = const {},
  Map<String, List<String>> paid = const {},
  DateTime? paidAt,
  DateTime? postedAt,
}) {
  return CorporateJobPost(
    id: 'post-1',
    title: '테스트 공고',
    warehouseName: '센터',
    hourlyWage: '10,000원',
    workSchedule: '09-18',
    summary: '요약',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 0,
    postedAt: postedAt ?? DateTime(2026, 6, 1),
    linkedCommuteRouteIds: registered.keys.toList(),
    shuttleRegisteredStopIdsByRoute: registered,
    shuttlePaidStopIdsByRoute: paid,
    shuttleExposurePaidAt: paidAt,
    hasShuttleRouteOverlay: overlay,
  );
}

CommuteRouteStop _stop(String id, {bool activated = false}) =>
    CommuteRouteStop(
      id: id,
      label: id,
      coordinate: const GeoCoordinate(latitude: 37.0, longitude: 127.0),
      exposureActivated: activated,
    );

CommuteRoute _route(String id, List<CommuteRouteStop> stops) => CommuteRoute(
      id: id,
      companyKey: 'co',
      routeName: id,
      stops: stops,
    );

void main() {
  group('isShuttleExposureActive', () {
    test('is true when overlay on and paid map exists without paidAt', () {
      final post = _post(
        paid: {'route-a': ['s1', 's2']},
        paidAt: null,
      );

      expect(post.isShuttleExposureActive, isTrue);
    });

    test('is false when overlay off even with paid map', () {
      final post = _post(
        overlay: false,
        paid: {'route-a': ['s1']},
        paidAt: DateTime(2026, 6, 1),
      );

      expect(post.isShuttleExposureActive, isFalse);
    });

    test('is false when exposure period expired', () {
      final paidAt = DateTime(2020, 1, 1);
      final post = _post(
        paid: {'route-a': ['s1']},
        paidAt: paidAt,
        postedAt: paidAt,
      );

      expect(
        JobPostValidity.isExpired(post.shuttleExposureExpiresAt!),
        isTrue,
      );
      expect(post.isShuttleExposureActive, isFalse);
    });
  });

  group('resolveShuttleExposureMetadata', () {
    test('backfills paidAt when paid map exists alone', () {
      final post = _post(
        paid: {'route-a': ['s1']},
        paidAt: null,
      );

      final resolved = post.resolveShuttleExposureMetadata();

      expect(resolved.shuttleExposurePaidAt, isNotNull);
      expect(resolved.shuttlePaidStopIdsByRoute, {'route-a': ['s1']});
      expect(resolved.hasShuttleRouteOverlay, isTrue);
    });

    test('does not mark unregistered stops as paid', () {
      final post = _post(
        registered: {'route-a': ['s1', 's2']},
        paid: const {},
        paidAt: null,
      );

      final resolved = post.resolveShuttleExposureMetadata();

      expect(resolved.shuttlePaidStopIdsByRoute['route-a'], ['s1', 's2']);
    });
  });

  group('isShuttleStopExposureLocked', () {
    test('locks only paid stops when per-route paid map exists', () {
      final post = _post(
        registered: {'route-a': ['s1', 's2', 's3']},
        paid: {'route-a': ['s1', 's2']},
        paidAt: DateTime(2026, 6, 18),
      );

      expect(post.isShuttleStopExposureLocked('route-a', 's1'), isTrue);
      expect(post.isShuttleStopExposureLocked('route-a', 's2'), isTrue);
      expect(post.isShuttleStopExposureLocked('route-a', 's3'), isFalse);
    });

    test('does not lock stop from route exposureActivated alone', () {
      final post = _post(
        registered: {'route-a': ['s1', 's2']},
        paid: {'route-a': ['s1']},
        paidAt: DateTime(2026, 6, 18),
      );

      expect(post.isShuttleStopExposureLocked('route-a', 's2'), isFalse);
    });

    test('does not lock new stop on route missing from paid map', () {
      final post = _post(
        registered: {
          'route-a': ['a1'],
          'route-b': ['b1', 'b2'],
        },
        paid: {
          'route-a': ['a1'],
          'route-b': ['b1'],
        },
        paidAt: DateTime(2026, 6, 18),
      );

      expect(post.isShuttleStopExposureLocked('route-b', 'b2'), isFalse);
    });
  });

  group('reconcileShuttleExposureWithRoutes', () {
    test('merges exposureActivated stops into paid map', () {
      final post = _post(
        registered: {
          'route-a': ['s1', 's2'],
        },
        paid: {'route-a': ['s1']},
        paidAt: DateTime(2026, 6, 18),
      );
      final routes = [
        _route('route-a', [
          _stop('s1', activated: true),
          _stop('s2', activated: true),
        ]),
      ];

      final reconciled = post.reconcileShuttleExposureWithRoutes(routes);

      expect(reconciled.shuttlePaidStopIdsByRoute['route-a'], contains('s2'));
      expect(reconciled.isShuttleStopExposureLocked('route-a', 's2'), isTrue);
    });

    test('does not add unregistered exposureActivated stops', () {
      final post = _post(
        registered: {'route-a': ['s1']},
        paid: {'route-a': ['s1']},
        paidAt: DateTime(2026, 6, 18),
      );
      final routes = [
        _route('route-a', [
          _stop('s1', activated: true),
          _stop('s2', activated: true),
        ]),
      ];

      final reconciled = post.reconcileShuttleExposureWithRoutes(routes);

      expect(reconciled.shuttlePaidStopIdsByRoute['route-a'], ['s1']);
    });

    test('does not inherit route exposureActivated for unpaid post', () {
      final post = _post(
        overlay: false,
        registered: {'route-a': ['s1', 's2']},
      );
      final routes = [
        _route('route-a', [
          _stop('s1', activated: true),
          _stop('s2', activated: true),
        ]),
      ];

      final reconciled = post.reconcileShuttleExposureWithRoutes(routes);

      expect(reconciled.shuttlePaidStopIdsByRoute, isEmpty);
      expect(reconciled.hasShuttleRouteOverlay, isFalse);
      expect(reconciled.isShuttleExposureActive, isFalse);
      expect(reconciled.isShuttleStopExposureLocked('route-a', 's1'), isFalse);
    });
  });

  group('unpaidRegisteredShuttleStopCount', () {
    test('counts only unlocked registered stops', () {
      final post = _post(
        registered: {
          'route-a': ['s1', 's2'],
          'route-b': ['s3'],
        },
        paid: {
          'route-a': ['s1'],
          'route-b': ['s3'],
        },
        paidAt: DateTime(2026, 6, 18),
      );

      expect(post.unpaidRegisteredShuttleStopCount, 1);
    });
  });
}
