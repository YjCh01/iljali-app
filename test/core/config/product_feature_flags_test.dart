import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

void main() {
  group('ProductFeatureFlags MVP defaults', () {
    test('worker general is disabled; contract is enabled by default', () {
      expect(ProductFeatureFlags.isWorkerGeneralEnabled, isFalse);
      expect(ProductFeatureFlags.isWorkerContractEnabled, isTrue);
    });

    test('permanent hire is disabled', () {
      expect(ProductFeatureFlags.isPermanentHireEnabled, isFalse);
    });

    test('logistics-focused flows stay enabled', () {
      expect(ProductFeatureFlags.isPremiumPartnerWizardEnabled, isTrue);
      expect(ProductFeatureFlags.isEnterpriseOutsourcingEnabled, isTrue);
    });

    test('allowedWorkerCategories includes daily, shortTerm, regular, and contract', () {
      expect(
        ProductFeatureFlags.allowedWorkerCategories,
        equals([
          WorkerCategory.daily,
          WorkerCategory.shortTerm,
          WorkerCategory.regular,
          WorkerCategory.contract,
        ]),
      );
    });

    test('defaultWorkerCategory is shortTerm when general disabled', () {
      expect(ProductFeatureFlags.defaultWorkerCategory, WorkerCategory.shortTerm);
    });

    test('disabledFeatures registry is not empty', () {
      expect(ProductFeatureFlags.disabledFeatures, isNotEmpty);
    });

    test('disabledFeatures contains expected ids', () {
      final ids =
          ProductFeatureFlags.disabledFeatures.map((f) => f.id).toList();
      expect(ids, containsAll(['worker_general', 'permanent_hire']));
      expect(ids, isNot(contains('worker_contract')));
    });

    test('listDisabledFeatures returns human-readable entries', () {
      final lines = ProductFeatureFlags.listDisabledFeatures();
      expect(lines, isNotEmpty);
      expect(lines.first, contains('일반직'));
    });
  });
}
