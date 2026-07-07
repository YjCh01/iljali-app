import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

/// 폼 필드용 근무 일정 요약 (칩·줄바꿈)
class WorkSchedulePreviewModel {
  const WorkSchedulePreviewModel({
    required this.headline,
    this.chips = const [],
    this.lines = const [],
  });

  final String headline;
  final List<String> chips;
  final List<String> lines;

  bool get needsExpand =>
      chips.length > WorkScheduleFieldPreview.collapsedChipLimit;
}

abstract final class WorkSchedulePreviewFormatter {
  static WorkSchedulePreviewModel? fromRaw(String raw) {
    if (WorkScheduleNegotiable.isLabel(raw)) {
      return WorkSchedulePreviewModel(
        headline: WorkScheduleNegotiable.label,
      );
    }
    final spec = WorkScheduleCodec.tryParse(raw);
    if (spec == null) return null;
    if (!spec.isComplete && !spec.firstStartDateOnly) return null;

    final dayTime =
        '${_padTime(spec.dayStart)}~${_padTime(spec.dayEnd)}';
    final regularPrefix = spec.firstStartDateOnly ? '정규 · ' : '';

    return switch (spec.mode) {
      WorkScheduleMode.dailyPick => () {
          final sorted = spec.selectedWorkDates.toList()
            ..sort((a, b) => a.compareTo(b));
          if (spec.hasVariedDailyHours) {
            return WorkSchedulePreviewModel(
              headline: '일용 · 날짜별 시간 · ${sorted.length}일',
              chips: sorted
                  .map((date) {
                    final hours = spec.hoursForDate(date);
                    return '${_fmtChipDate(date)} '
                        '${_padTime(hours.start)}~${_padTime(hours.end)}';
                  })
                  .toList(),
            );
          }
          return WorkSchedulePreviewModel(
            headline: '일용 · $dayTime · ${sorted.length}일',
            chips: sorted.map(_fmtChipDate).toList(),
          );
        }(),
      WorkScheduleMode.fixedWeekdays => () {
          final days = WorkScheduleSpec.weekdayLabels
              .asMap()
              .entries
              .where((e) => spec.weekdays.contains(e.key))
              .map((e) => e.value)
              .join('');
          final periodLine = spec.firstStartDateOnly
              ? (spec.startDate != null
                  ? '첫 근무 ${_fmtDate(spec.startDate!)}'
                  : '첫 근무 · 협의')
              : '${_fmtDate(spec.startDate!)} ~ ${_fmtDate(spec.endDate!)}';
          if (spec.hasVariedWeekdayHours) {
            final chips = (spec.weekdays.toList()..sort())
                .map((index) {
                  final hours = spec.hoursForWeekday(index);
                  return '${WorkScheduleSpec.weekdayLabels[index]} '
                      '${_padTime(hours.start)}~${_padTime(hours.end)}';
                })
                .toList();
            return WorkSchedulePreviewModel(
              headline: '$regularPrefix주${spec.weekdays.length}일($days)',
              lines: [periodLine],
              chips: chips,
            );
          }
          return WorkSchedulePreviewModel(
            headline: '$regularPrefix주${spec.weekdays.length}일($days)',
            lines: [
              periodLine,
              dayTime,
            ],
          );
        }(),
      WorkScheduleMode.rotatingShift => () {
          final preset = RotatingShiftPreset.byId(spec.rotatingPresetId);
          final label = preset?.title ?? '교대';
          final nightTime =
              '${_padTime(spec.nightStart)}~${_padTime(spec.nightEnd)}';
          final periodLine = spec.firstStartDateOnly
              ? (spec.startDate != null
                  ? '첫 근무 ${_fmtDate(spec.startDate!)}'
                  : '첫 근무 · 협의')
              : '${_fmtDate(spec.startDate!)} ~ ${_fmtDate(spec.endDate!)}';
          return WorkSchedulePreviewModel(
            headline: '$regularPrefix교대 · $label',
            lines: [
              periodLine,
              '주 $dayTime · 야 $nightTime',
            ],
          );
        }(),
      WorkScheduleMode.customDates => () {
          final excluded = spec.customExcludedDates.toList()
            ..sort((a, b) => a.compareTo(b));
          final periodLine = spec.firstStartDateOnly
              ? (spec.startDate != null
                  ? '첫 근무 ${_fmtDate(spec.startDate!)}'
                  : '첫 근무 · 협의')
              : '${_fmtDate(spec.startDate!)} ~ ${_fmtDate(spec.endDate!)}';
          final workDays = spec.countWorkDays();
          if (spec.hasVariedWeekdayHours) {
            final chips = List<int>.generate(7, (i) => i)
                .map((index) {
                  final hours = spec.hoursForWeekday(index);
                  return '${WorkScheduleSpec.weekdayLabels[index]} '
                      '${_padTime(hours.start)}~${_padTime(hours.end)}';
                })
                .toList();
            return WorkSchedulePreviewModel(
              headline: spec.firstStartDateOnly
                  ? '$regularPrefix맞춤 · 요일별 시간'
                  : '맞춤 · 요일별 시간 · $workDays일',
              lines: [periodLine],
              chips: [
                ...chips,
                ...excluded.map((d) => '제외 ${_fmtChipDate(d)}'),
              ],
            );
          }
          return WorkSchedulePreviewModel(
            headline: spec.firstStartDateOnly
                ? '$regularPrefix맞춤 · $dayTime'
                : '맞춤 · $dayTime · $workDays일',
            lines: [periodLine],
            chips: excluded.map((d) => '제외 ${_fmtChipDate(d)}').toList(),
          );
        }(),
    };
  }

  static String _padTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  static String _fmtChipDate(DateTime d) => formatChipDate(d);

  static String formatChipDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final w = weekdays[WorkScheduleSpec.weekdayIndex(d)];
    return '${d.month}/${d.day}($w)';
  }
}

/// 근무 일정 필드 미리보기 — 칩 그리드
class WorkScheduleFieldPreview extends StatelessWidget {
  const WorkScheduleFieldPreview({
    super.key,
    required this.raw,
    this.placeholder = '근무 일정 선택',
    this.expanded = false,
  });

  final String raw;
  final String placeholder;
  final bool expanded;

  static const collapsedChipLimit = 6;

  @override
  Widget build(BuildContext context) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return Text(
        placeholder,
        style: TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
      );
    }

    final model = WorkSchedulePreviewFormatter.fromRaw(trimmed);
    if (model == null) {
      return Text(
        trimmed,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      );
    }

    final showExpand = model.needsExpand;
    final visibleChips = showExpand && !expanded
        ? model.chips.take(collapsedChipLimit).toList()
        : model.chips;
    final hiddenCount = model.chips.length - visibleChips.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.headline,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        for (final line in model.lines) ...[
          const SizedBox(height: 4),
          Text(
            line,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ],
        if (visibleChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in visibleChips) _DateChip(label: chip),
              if (showExpand && !expanded && hiddenCount > 0)
                _MoreChip(label: '+$hiddenCount'),
            ],
          ),
        ],
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}
