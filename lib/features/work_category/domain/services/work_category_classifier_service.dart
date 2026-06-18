import 'package:map/features/work_category/domain/entities/work_category_catalog.dart';
import 'package:map/features/work_category/domain/entities/work_category_definition.dart';

/// 공고 제목·업무 내용에서 업무 카테고리 자동 추론 (로컬 MVP)
abstract final class WorkCategoryClassifierService {
  static WorkCategoryDefinition classify({
    required String title,
    String jobDescription = '',
    String summary = '',
  }) {
    final blob = '$title $jobDescription $summary'.toLowerCase();

    WorkCategoryDefinition? best;
    var bestScore = 0;

    for (final category in WorkCategoryCatalog.all) {
      if (category.id == WorkCategoryCatalog.other.id) continue;
      var score = 0;
      for (final keyword in category.keywords) {
        if (blob.contains(keyword.toLowerCase())) {
          score += keyword.length >= 3 ? 2 : 1;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = category;
      }
    }

    return best ?? WorkCategoryCatalog.other;
  }

  static String resolveCategoryId({
    String? selectedId,
    required String title,
    String jobDescription = '',
    String summary = '',
  }) {
    final manual = WorkCategoryCatalog.findById(selectedId);
    if (manual != null && manual.id != WorkCategoryCatalog.other.id) {
      return manual.id;
    }
    return classify(
      title: title,
      jobDescription: jobDescription,
      summary: summary,
    ).id;
  }
}
