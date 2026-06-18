import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 카드·미리보기 공통 라벨 문구
abstract final class CorporateJobPostDisplayLabels {
  static const siteLocation = '소재지';
  static const salary = '급여';
  static const paymentSchedule = '급여 지급일';
  static const workSchedule = '근무일시';
}

/// 공고 카드·미리보기 공통 표시 값
abstract final class CorporateJobPostDisplayValues {
  static String siteLocation(CorporateJobPost post) {
    return post.branchName != null
        ? '${post.branchName} · ${post.warehouseName}'
        : post.warehouseName;
  }

  /// [hourlyWage]는 `formatCorporateHourlyWage`로 이미 「시급 10,320원」 형태.
  static String salary(CorporateJobPost post) {
    final wage = post.hourlyWage.trim();
    if (post.dailyWage != null) {
      return '$wage · 일급 ${post.dailyWage}';
    }
    return wage;
  }

  static String? paymentSchedule(CorporateJobPost post) =>
      post.paymentScheduleDisplayLabel;

  /// 근무일정 문자열에서 고용형태 접두(일용 등)를 제거한 값.
  static String workSchedule(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('일용 · ')) {
      return trimmed.substring('일용 · '.length);
    }
    if (trimmed.startsWith('일용·')) {
      return trimmed.substring('일용·'.length).trimLeft();
    }
    return trimmed;
  }
}

/// 공고 카드·미리보기 — 굵은 라벨 + 일반 값 행
class CorporateJobPostLabeledInfoRow extends StatelessWidget {
  const CorporateJobPostLabeledInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconSize = 16,
    this.spacing = 6,
    this.fontSize = 14,
    this.bottomPadding = 0,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final double iconSize;
  final double spacing;
  final double fontSize;
  final double bottomPadding;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: valueColor ?? AppColors.textPrimary,
      height: 1.4,
    );
    final labelStyle = valueStyle.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label, style: labelStyle),
                  TextSpan(text: ' $value', style: valueStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
