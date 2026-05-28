import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/utils/branch_plan_limits.dart';

void main() {
  group('BranchPlanLimits', () {
    test('all tiers default to base location slots without wallet', () {
      for (final tier in PremiumPartnershipTier.values) {
        expect(
          BranchPlanLimits.maxBranches(tier),
          PushPackageCatalog.baseLocationSlots,
        );
        expect(
          BranchPlanLimits.limitLabel(tier),
          '${PushPackageCatalog.baseLocationSlots}곳',
        );
      }
    });
  });
}
