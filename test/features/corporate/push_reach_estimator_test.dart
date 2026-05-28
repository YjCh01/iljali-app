import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';

void main() {
  test('estimateRecruitmentRights sums 20~25 per slot', () {
    expect(
      PushReachEstimator.estimateRecruitmentRights(1, seed: 1),
      inInclusiveRange(20, 25),
    );
    expect(
      PushReachEstimator.estimateRecruitmentRights(8, seed: 99),
      inInclusiveRange(160, 200),
    );
  });

  test('estimateForSettings uses all active base points', () {
    final settings = JobPostNotificationSettings(
      basePoints: List.generate(
        8,
        (i) => PushNotificationBasePoint(
          id: 'p$i',
          coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
          addressLabel: '모집지역 $i',
          radiusTier: PushRadiusTier.standard1km,
          isPrimary: i == 0,
        ),
      ),
    );

    expect(
      PushReachEstimator.recruitmentSlotCountFromSettings(settings),
      8,
    );
    expect(
      PushReachEstimator.estimateForSettings(settings, seed: 7),
      inInclusiveRange(160, 200),
    );
  });

  test('single slot dispatch stays in 20~25 band', () {
    expect(
      PushReachEstimator.estimate(PushRadiusTier.standard1km),
      inInclusiveRange(20, 25),
    );
  });
}
