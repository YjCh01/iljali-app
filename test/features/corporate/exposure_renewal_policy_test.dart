import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/services/employer_cash_balance_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_renewal_policy.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';

void main() {
  test('renewActivation resets exposurePaidAt', () {
    final oldPaid = DateTime(2020, 1, 1);
    final point = PushNotificationBasePoint(
      id: 'p1',
      coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
      addressLabel: '강남',
      exposureActivated: true,
      exposurePaidAt: oldPaid,
    );
    final renewed = ExposureSlotPolicy.renewActivation(point);
    expect(renewed.exposurePaidAt, isNot(equals(oldPaid)));
    expect(renewed.isExposureLocked, isTrue);
  });

  test('collects expired job pin for renewal', () {
    final paidAt = DateTime(2020, 1, 1, 12);
    final post = CorporateJobPost(
      id: 'post1',
      title: '야간',
      warehouseName: '센터',
      hourlyWage: '10,000원',
      workSchedule: '주5일',
      summary: '요약',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: paidAt,
      notificationSettings: JobPostNotificationSettings(
        basePoints: [
          PushNotificationBasePoint(
            id: 'w',
            coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
            addressLabel: '근무지',
            isPrimary: true,
          ),
          PushNotificationBasePoint(
            id: 'pin1',
            coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.01),
            addressLabel: '알림핀1',
            exposureActivated: true,
            exposurePaidAt: paidAt,
          ),
        ],
      ),
    );

    final candidates = ExposureRenewalPolicy.collectForPost(
      post: post,
      routesById: const {},
      now: DateTime(2026, 1, 1),
    );

    expect(candidates, hasLength(1));
    expect(candidates.first.kind, ExposureRenewalCandidateKind.jobPin);
    expect(candidates.first.urgency, ExposureRenewalUrgency.expired);
  });

  test('cash balance label formats with commas', () {
    const wallet = EmployerPushWallet(cashBalanceKrw: 150000);
    expect(wallet.cashBalanceLabel, '150,000원');
  });

  test('preset charge amounts are sensible', () {
    expect(EmployerCashBalanceService.presetAmountsKrw.first, greaterThanOrEqualTo(10000));
  });

  test('post expires end of next day unchanged', () {
    final posted = DateTime(2026, 5, 28, 10);
    final expires = JobPostValidity.expiresAtFromRegistration(posted);
    expect(expires, DateTime(2026, 5, 29, 23, 59, 59));
  });
}
