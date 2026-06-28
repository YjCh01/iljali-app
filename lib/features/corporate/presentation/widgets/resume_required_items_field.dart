import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_form.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';

/// 공고 — 지원자 이력서 필수 확인 항목
class ResumeRequiredItemsField extends StatelessWidget {
  const ResumeRequiredItemsField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<ResumeItemKind> selected;
  final ValueChanged<List<ResumeItemKind>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('지원자 이력서 필수 확인 항목'),
        Text(
          '선택한 항목은 지원 시 구직자에게 공개 동의를 요청합니다.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ResumeItemKind.values.map((kind) {
            final checked = selected.contains(kind);
            return FilterChip(
              label: Text(kind.label),
              selected: checked,
              onSelected: (value) {
                final next = List<ResumeItemKind>.from(selected);
                if (value) {
                  if (!next.contains(kind)) next.add(kind);
                } else {
                  next.remove(kind);
                }
                onChanged(next);
              },
              selectedColor: AppColors.primaryLight.withValues(alpha: 0.35),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }
}
