import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

void main() {
  group('ProductFeatureFlags MVP defaults', () {
    test('worker general and contract are disabled', () {
      expect(ProductFeatureFlags.isWorkerGeneralEnabled, isFalse);
      expect(ProductFeatureFlags.isWorkerContractEnabled, isFalse);
    });

    test('permanent hire is disabled', () {
      expect(ProductFeatureFlags.isPermanentHireEnabled, isFalse);
    });

    test('logistics-focused flows stay enabled', () {
      expect(ProductFeatureFlags.isPremiumPartnerWizardEnabled, isTrue);
      expect(ProductFeatureFlags.isEnterpriseOutsourcingEnabled, isTrue);
    });

    test('allowedWorkerCategories is daily only', () {
      expect(
        ProductFeatureFlags.allowedWorkerCategories,
        equals([WorkerCategory.daily]),
      );
    });

    test('defaultWorkerCategory is daily when general disabled', () {
      expect(ProductFeatureFlags.defaultWorkerCategory, WorkerCategory.daily);
    });

    test('disabledFeatures registry is not empty', () {
      expect(ProductFeatureFlags.disabledFeatures, isNotEmpty);
    });

    test('disabledFeatures contains expected ids', () {
      final ids =
          ProductFeatureFlags.disabledFeatures.map((f) => f.id).toList();
      expect(ids, containsAll(['worker_general', 'worker_contract', 'permanent_hire']));
    });

    test('listDisabledFeatures returns human-readable entries', () {
      final lines = ProductFeatureFlags.listDisabledFeatures();
      expect(lines, isNotEmpty);
      expect(lines.first, contains('일반직'));
    });
  });
}
