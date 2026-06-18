import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/branch_hierarchy_validator.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';

void main() {
  group('PushPlanEnforcement', () {
    test('default plan allows only 1km radius', () {
      expect(
        PushPlanEnforcement.isRadiusAllowed(PushRadiusTier.standard1km),
        isTrue,
      );
      expect(
        PushPlanEnforcement.isRadiusAllowed(PushRadiusTier.extended3km),
        isFalse,
      );
    });

    test('clampRadius downgrades out-of-plan tier', () {
      final clamped =
          PushPlanEnforcement.clampRadius(PushRadiusTier.extended7km);
      expect(clamped.radiusKm, lessThanOrEqualTo(1));
    });

    test('planLimitSummary mentions free workplace exposure', () {
      final summary = PushPlanEnforcement.planLimitSummary();
      expect(summary, contains('근무지'));
      expect(summary, contains('무료'));
      expect(summary, contains('일자리 알림핀'));
    });
  });

  group('BranchHierarchyValidator', () {
    test('regional requires hq parent', () {
      expect(
        BranchHierarchyValidator.validateCreate(
          level: BranchLevel.regional,
          parentBranchId: null,
          existing: const [],
        ),
        isNotNull,
      );
    });

    test('store cannot parent to store', () {
      const parent = CorporateBranch(
        id: 's1',
        companyKey: 'c1',
        name: '매장A',
        roadAddress: 'addr',
        level: BranchLevel.store,
      );
      expect(
        BranchHierarchyValidator.validateCreate(
          level: BranchLevel.store,
          parentBranchId: 's1',
          existing: const [parent],
        ),
        isNotNull,
      );
    });
  });
}
