import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

void main() {
  group('PremiumPartnershipTier legacy shim', () {
    test('all tiers map to default push package catalog', () {
      for (final tier in PremiumPartnershipTier.values) {
        expect(tier.label, PushPackageCatalog.defaultPlanLabel);
        expect(tier.monthlyPriceKrwMin, 0);
        expect(tier.pushRadiusM, PushPackageCatalog.freePushRadiusM);
        expect(tier.dailyPushLimit, PushPackageCatalog.dailyFreePush);
        expect(tier.extraPushPriceKrw, PushPackageCatalog.singlePackagePriceKrw);
        expect(tier.isPaid, isFalse);
      }
    });

    test('PartnershipPlanDefaults.activePlan is basic', () {
      expect(PartnershipPlanDefaults.activePlan, PremiumPartnershipTier.basic);
    });

    test('PremiumPartnershipPlans.buildChatNoticeBody matches push policy', () {
      final body = PremiumPartnershipPlans.buildChatNoticeBody();
      expect(body, contains('공고 등록'));
      expect(body, contains('근무지 1km'));
      expect(body, contains('유료 지역 푸시권'));
      expect(body, contains('1km'));
    });
  });
}
