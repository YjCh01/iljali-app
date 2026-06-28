import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

CorporateJobPost _post({
  JobPostNotificationSettings? settings,
  bool shuttleOverlay = false,
}) {
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
    hasShuttleRouteOverlay: shuttleOverlay,
  );
}

void main() {
  group('ExposureSlotPolicy', () {
    test('blocks push ticket on unactivated shuttle stop', () {
      const coord = GeoCoordinate(latitude: 37.5, longitude: 127.0);
      final post = _post();

      final reason = ExposureSlotPolicy.pushTicketBlockReason(
        post: post,
        target: PushDispatchTarget(
          id: 'stop_s1',
          kind: PushDispatchTargetKind.shuttleStop,
          title: '정류장 1',
          subtitle: 'TEST1 · 정류장',
          coordinate: coord,
          radiusMeters: 700,
          shuttleStopId: 's1',
          routeName: 'TEST1',
          exposureActivated: false,
        ),
      );

      expect(reason, isNotNull);
      expect(reason, contains('정류장 표시핀 결제'));
    });

    test('allows push on activated shuttle stop', () {
      const coord = GeoCoordinate(latitude: 37.5, longitude: 127.0);
      final post = _post();

      final reason = ExposureSlotPolicy.pushTicketBlockReason(
        post: post,
        target: PushDispatchTarget(
          id: 'stop_s1',
          kind: PushDispatchTargetKind.shuttleStop,
          title: '정류장 1',
          subtitle: 'TEST1 · 정류장',
          coordinate: coord,
          radiusMeters: 700,
          shuttleStopId: 's1',
          routeName: 'TEST1',
          exposureActivated: true,
        ),
      );

      expect(reason, isNull);
    });

    test('blocks push ticket on unactivated recruitment pin', () {
      const coord = GeoCoordinate(latitude: 37.5, longitude: 127.0);
      final post = _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            PushNotificationBasePoint(
              id: 'w',
              coordinate: coord,
              addressLabel: '근무지',
              radiusTier: PushRadiusTier.standardFree1km,
            ),
            PushNotificationBasePoint(
              id: 'pin1',
              coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
              addressLabel: '알림핀 1',
            ),
          ],
        ),
      );

      final reason = ExposureSlotPolicy.pushTicketBlockReason(
        post: post,
        target: PushDispatchTarget(
          id: 'pin_pin1',
          kind: PushDispatchTargetKind.notificationPin,
          title: '알림핀 1',
          subtitle: 'test',
          coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
          radiusMeters: 700,
          basePointId: 'pin1',
        ),
      );

      expect(reason, isNotNull);
      expect(reason, contains('노출 활성화'));
    });

    test('blocks push when pin moved from locked activation coordinate', () {
      const locked = GeoCoordinate(latitude: 37.51, longitude: 127.01);
      const moved = GeoCoordinate(latitude: 37.52, longitude: 127.02);
      final post = _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            PushNotificationBasePoint(
              id: 'w',
              coordinate: locked,
              addressLabel: '근무지',
              radiusTier: PushRadiusTier.standardFree1km,
            ),
            PushNotificationBasePoint(
              id: 'pin1',
              coordinate: moved,
              addressLabel: '알림핀 1',
              exposureActivated: true,
              activationCoordinate: locked,
            ),
          ],
        ),
      );

      final reason = ExposureSlotPolicy.pushTicketBlockReason(
        post: post,
        target: PushDispatchTarget(
          id: 'pin_pin1',
          kind: PushDispatchTargetKind.notificationPin,
          title: '알림핀 1',
          subtitle: 'test',
          coordinate: moved,
          radiusMeters: 700,
          basePointId: 'pin1',
        ),
      );

      expect(reason, contains('위치가 변경'));
    });

    test('allows push on activated pin at locked coordinate', () {
      const locked = GeoCoordinate(latitude: 37.51, longitude: 127.01);
      final post = _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            PushNotificationBasePoint(
              id: 'w',
              coordinate: locked,
              addressLabel: '근무지',
              radiusTier: PushRadiusTier.standardFree1km,
            ),
            PushNotificationBasePoint(
              id: 'pin1',
              coordinate: locked,
              addressLabel: '알림핀 1',
              exposureActivated: true,
              activationCoordinate: locked,
            ),
          ],
        ),
      );

      final reason = ExposureSlotPolicy.pushTicketBlockReason(
        post: post,
        target: PushDispatchTarget(
          id: 'pin_pin1',
          kind: PushDispatchTargetKind.notificationPin,
          title: '알림핀 1',
          subtitle: 'test',
          coordinate: locked,
          radiusMeters: 700,
          basePointId: 'pin1',
        ),
      );

      expect(reason, isNull);
    });

    test('syncPaidRecruitmentActivations heals premium pin without flag', () {
      const coord = GeoCoordinate(latitude: 37.51, longitude: 127.01);
      final points = [
        PushNotificationBasePoint(
          id: 'w',
          coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
          addressLabel: '근무지',
        ),
        PushNotificationBasePoint(
          id: 'pin1',
          coordinate: coord,
          addressLabel: '알림핀 1',
          isPremiumSlot: true,
        ),
      ];

      final synced = ExposureSlotPolicy.syncPaidRecruitmentActivations(points);

      expect(synced[1].exposureActivated, isTrue);
      expect(synced[1].activationCoordinate, coord);
      expect(
        ExposureSlotPolicy.pushTicketBlockReason(
          post: _post(
            settings: JobPostNotificationSettings(basePoints: synced),
          ),
          target: PushDispatchTarget(
            id: 'pin_pin1',
            kind: PushDispatchTargetKind.notificationPin,
            title: '알림핀 1',
            subtitle: 'test',
            coordinate: coord,
            radiusMeters: 700,
            basePointId: 'pin1',
          ),
        ),
        isNull,
      );
    });

    test('pre-activated new pin does not require extra billable credit', () {
      const before = [
        PushNotificationBasePoint(
          id: 'w',
          coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
          addressLabel: '근무지',
        ),
      ];
      final after = [
        ...before,
        ExposureSlotPolicy.lockActivation(
          PushNotificationBasePoint(
            id: 'pin_new',
            coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
            addressLabel: '알림핀 1',
          ),
        ),
      ];

      final billable = PushWalletCreditPolicy.extraPushBillableCredits(
        before: before,
        after: after,
        activePointIndex: 1,
      );

      expect(billable, 0);
    });
  });
}
