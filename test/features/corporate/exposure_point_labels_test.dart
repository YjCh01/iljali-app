import 'package:flutter_test/flutter_test.dart';

import 'package:map/core/geo/geo_coordinate.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';



void main() {

  test('ExposurePointLabels uses compact workplace vs recruitment naming', () {

    expect(ExposurePointLabels.title(0), '근무지');

    expect(ExposurePointLabels.title(1), '모집지역 1');

    expect(ExposurePointLabels.title(2), '모집지역 2');



    const point = PushNotificationBasePoint(

      id: 'base-1',

      coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),

      addressLabel: '포인트 2',

      radiusTier: PushRadiusTier.standard1km,

    );



    expect(ExposurePointLabels.zoneRowSubtitle(0), '무료 · 1km · 근무지 주변');

    expect(

      ExposurePointLabels.zoneRowSubtitle(1),

      '노출지역 · 1km',

    );



    expect(

      ExposurePointLabels.compactLine(0, point),

      '근무지 · 무료 · 1km · 근무지 주변',

    );

    expect(

      ExposurePointLabels.compactLine(1, point),

      '모집지역 1 · 노출지역 · 1km',

    );

    expect(

      ExposurePointLabels.addZoneButtonLabel(3),

      '모집지역 추가 (잔여 지역 푸시권 : 3)',

    );

    expect(ExposurePointLabels.addZoneButtonLabel(0), '추가 슬롯·지역 푸시권 없음');

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

          radiusTier: PushRadiusTier.standard1km,

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

      '근무지 · 무료 · 1km · 근무지 주변',

      '모집지역 1 · 노출지역 · 1km',

    ]);

  });

}


