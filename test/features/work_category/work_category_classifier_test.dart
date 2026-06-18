import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/work_category/domain/entities/work_category_catalog.dart';
import 'package:map/features/work_category/domain/services/work_category_classifier_service.dart';

void main() {
  group('WorkCategoryClassifierService', () {
    test('classifies logistics from title', () {
      final result = WorkCategoryClassifierService.classify(
        title: '쿠팡 물류센터 피킹 보조',
        jobDescription: '창고에서 분류 및 포장',
      );
      expect(result.id, anyOf('logistics', 'picking', 'sorting'));
    });

    test('classifies cleaning', () {
      final result = WorkCategoryClassifierService.classify(
        title: '빌딩 청소 아르바이트',
      );
      expect(result.id, WorkCategoryCatalog.cleaning.id);
    });

    test('classifies event staff', () {
      final result = WorkCategoryClassifierService.classify(
        title: '전시회 행사 스태프',
      );
      expect(result.id, WorkCategoryCatalog.eventStaff.id);
    });

    test('manual selection overrides AI', () {
      final id = WorkCategoryClassifierService.resolveCategoryId(
        selectedId: WorkCategoryCatalog.kitchenHelper.id,
        title: '물류센터 야간',
      );
      expect(id, WorkCategoryCatalog.kitchenHelper.id);
    });

    test('catalog has 30 categories', () {
      expect(WorkCategoryCatalog.all.length, 30);
    });
  });
}
