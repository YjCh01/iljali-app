import 'package:flutter_test/flutter_test.dart';

import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';

import 'package:map/features/corporate/domain/entities/recruitment_product_kind.dart';



void main() {

  group('PushPackageCatalog', () {

    test('exposure pin/stop is 19,900 KRW', () {

      expect(PushPackageCatalog.exposureUnitPriceKrw, 19900);

      final jobPin = PushPackageCatalog.findById('job_pin_single')!;

      final stopPin = PushPackageCatalog.findById('shuttle_pin_single')!;

      expect(jobPin.kind, RecruitmentProductKind.exposureOnly);

      expect(stopPin.kind, RecruitmentProductKind.exposureOnly);

      expect(jobPin.priceKrw, 19900);

      expect(stopPin.priceKrw, 19900);

    });



    test('exposure + push combo price constant is 35,900 KRW', () {

      expect(PushPackageCatalog.exposureWithPushUnitPriceKrw, 35900);

    });



    test('push-only ticket is 19,900 KRW', () {

      expect(PushTicketCatalog.unitPriceKrw, 19900);

      final push = PushPackageCatalog.findById('push_single')!;

      expect(push.kind, RecruitmentProductKind.pushOnly);

    });



    test('each product has 10-pack at 10% off', () {

      expect(PushPackageCatalog.findById('job_pin_pack_10')!.priceKrw, 179100);

      expect(

        PushPackageCatalog.findById('shuttle_pin_pack_10')!.priceKrw,

        179100,

      );

      expect(PushPackageCatalog.findById('push_pack_10')!.priceKrw, 179100);

    });



    test('six SKUs — 3 shop sections × (single + 10-pack)', () {

      expect(PushPackageCatalog.allOffers.length, 6);

      expect(PushPackageCatalog.shopSections.length, 3);

      for (final section in PushPackageCatalog.shopSections) {

        expect(

          PushPackageCatalog.resolveShopSectionOffers(section).length,

          2,

        );

      }

    });



    test('exposure ends D+1 23:59:59 after payment', () {

      expect(

        PushPackageCatalog.exposureEndsLabel,

        '적용 후 D+1 23:59:59까지',

      );

    });



    test('legacy single/pack_10 ids resolve to job pin offers', () {

      expect(PushPackageCatalog.findById('single')!.id, 'job_pin_single');

      expect(PushPackageCatalog.findById('pack_10')!.id, 'job_pin_pack_10');

      expect(PushPackageCatalog.findById('exposure_single')!.id, 'job_pin_single');

      expect(

        PushPackageCatalog.findById('exposure_pack_10')!.id,

        'job_pin_pack_10',

      );

    });

    test('shop section order matches product priority', () {
      final titles =
          PushPackageCatalog.shopSections.map((s) => s.title).toList();
      expect(titles, [
        '일자리 알림핀',
        '정류장 표시핀',
        'PUSH 이용권',
      ]);
    });

    test('exposure bundle labels do not collide with push ticket at same price', () {
      const fourStops = PushPaymentBundle(
        radiusTier: PushRadiusTier.standard1km,
        pointTier: DesignatedPointTier.onePoint,
        spotCount: 4,
        isExtraPush: true,
        extraPushFeeKrw: 4 * PushPackageCatalog.exposureUnitPriceKrw,
        paymentKind: JobPostPaymentRequestKind.shuttleStopExposure,
      );
      const pushTicket = PushPaymentBundle.pushTicket(spotCount: 4);

      expect(fourStops.productSummary, '정류장 표시핀 4곳');
      expect(fourStops.checkoutProductTitle, '정류장 표시핀 · 정류장 표시핀 4곳');
      expect(fourStops.checkoutBreakdownLabel, '정류장 표시핀 노출');
      expect(pushTicket.productSummary, 'PUSH 알림권 4회');
      expect(pushTicket.checkoutProductTitle, 'PUSH 알림권 · PUSH 알림권 4회');
    });
  });
}

