import 'package:flutter_test/flutter_test.dart';

import 'package:map/core/geo/geo_coordinate.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

void main() {
  test('ExposurePointLabels uses workplace vs notification pin naming', () {
    expect(ExposurePointLabels.title(0), '근무지');
    expect(ExposurePointLabels.title(1), '일자리 알림핀 1');
    expect(ExposurePointLabels.title(2), '일자리 알림핀 2');

    const point = PushNotificationBasePoint(
      id: 'base-1',
      coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
      addressLabel: '포인트 2',
      radiusTier: PushRadiusTier.standard1km,
    );

    expect(
      ExposurePointLabels.zoneRowSubtitle(0),
      '',
    );
    expect(
      ExposurePointLabels.zoneRowSubtitle(1),
      '',
    );

    expect(
      ExposurePointLabels.compactLine(0, point),
      '근무지',
    );
    expect(
      ExposurePointLabels.compactLine(1, point),
      '일자리 알림핀 1',
    );
    expect(ExposurePointLabels.addZoneButtonLabel(3), '일자리 알림핀 추가');
    expect(ExposurePointLabels.addZoneButtonLabel(0), '일자리 알림핀 추가');
    expect(ExposurePointLabels.radiusUi(PushRadiusTier.standard1km), '주변');
    expect(ExposurePointLabels.slotCount(2, 8), '2/8곳');
  });

  test('JobPostNotificationSettings exposurePointLabels are concise', () {
    final settings = JobPostNotificationSettings(
      basePoints: [
        const PushNotificationBasePoint(
          id: 'a',
          coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
          addressLabel: '근무지',
          radiusTier: PushRadiusTier.standardFree1km,
          isPrimary: true,
        ),
        const PushNotificationBasePoint(
          id: 'b',
          coordinate: GeoCoordinate(latitude: 37.51, longitude: 127.01),
          addressLabel: '포인트 2',
          radiusTier: PushRadiusTier.standard1km,
          isPremiumSlot: true,
        ),
      ],
    );

    expect(settings.exposurePointLabels, [
      '근무지',
      '일자리 알림핀 1',
    ]);
  });
}
