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
      expect(body, contains('가입·검증 보너스'));
      expect(body, contains('일자리 알림핀'));
      expect(body, contains('${PushPackageCatalog.signupBonusPushes}회'));
    });
  });
}
