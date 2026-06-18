import 'package:flutter/material.dart';

/// 단기·일용 현장 업무 카테고리 (업적 뱃지)
class WorkCategoryDefinition {
  const WorkCategoryDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.keywords,
  });

  final String id;
  final String label;
  final IconData icon;

  /// AI·키워드 자동 분류용 (소문자·공백 없음 비교)
  final List<String> keywords;
}
