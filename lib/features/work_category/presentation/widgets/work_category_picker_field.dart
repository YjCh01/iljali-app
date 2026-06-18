import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/work_category/domain/entities/work_category_catalog.dart';
import 'package:map/features/work_category/domain/entities/work_category_definition.dart';
import 'package:map/features/work_category/domain/services/work_category_classifier_service.dart';
import 'package:map/features/work_category/presentation/widgets/work_achievement_badge_icon.dart';

/// 공고 작성 — 업무 카테고리 (기본 접힘, AI 자동 권장)
class WorkCategoryPickerField extends StatefulWidget {
  const WorkCategoryPickerField({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.title = '',
    this.jobDescription = '',
  });

  /// null = AI 자동 분류
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String title;
  final String jobDescription;

  @override
  State<WorkCategoryPickerField> createState() =>
      _WorkCategoryPickerFieldState();
}

class _WorkCategoryPickerFieldState extends State<WorkCategoryPickerField> {
  bool _expanded = false;

  WorkCategoryDefinition? get _previewDef {
    if (widget.selectedId == null && widget.title.trim().isNotEmpty) {
      return WorkCategoryClassifierService.classify(
        title: widget.title,
        jobDescription: widget.jobDescription,
      );
    }
    return WorkCategoryCatalog.findById(widget.selectedId);
  }

  String get _summaryLabel {
    if (widget.selectedId == null) return 'AI 자동';
    return _previewDef?.label ?? '직접 선택';
  }

  @override
  Widget build(BuildContext context) {
    final previewDef = _previewDef;
    final isAi = widget.selectedId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    isAi ? Icons.auto_awesome : previewDef?.icon ?? Icons.work_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summaryLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isAi
                              ? '등록 시 업무 내용으로 자동 분류 (권장)'
                              : '직접 지정됨 · 탭해서 변경',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _expanded ? '접기' : '직접 고르기',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.95),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_expanded && isAi && previewDef != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              WorkAchievementBadgeIcon(
                definition: previewDef,
                count: 0,
                size: 28,
                dimmed: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI 추천 미리보기 · ${previewDef.label}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_expanded) ...[
          const SizedBox(height: 12),
          Text(
            '대부분 AI 자동으로 충분합니다. 필요할 때만 골라 주세요.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AutoChip(
                selected: widget.selectedId == null,
                onTap: () {
                  widget.onChanged(null);
                  setState(() => _expanded = false);
                },
              ),
              for (final def in WorkCategoryCatalog.all)
                if (def.id != WorkCategoryCatalog.other.id)
                  _CategoryChip(
                    definition: def,
                    selected: widget.selectedId == def.id,
                    onTap: () {
                      widget.onChanged(def.id);
                      setState(() => _expanded = false);
                    },
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AutoChip extends StatelessWidget {
  const _AutoChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: true,
      avatar: Icon(
        Icons.auto_awesome,
        size: 16,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      label: const Text('AI 자동'),
      onSelected: (_) => onTap(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final WorkCategoryDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: true,
      avatar: Icon(
        definition.icon,
        size: 16,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      label: Text(definition.label),
      onSelected: (_) => onTap(),
    );
  }
}
