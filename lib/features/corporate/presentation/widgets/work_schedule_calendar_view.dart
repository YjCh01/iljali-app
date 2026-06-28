import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/korean_calendar.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_calendar_utils.dart';

/// 공고 근무 일정 달력 (기업 등록 일정 그대로 표시 + 지원자 선택 오버레이)
class WorkScheduleCalendarView extends StatelessWidget {
  const WorkScheduleCalendarView({
    super.key,
    required this.spec,
    required this.months,
    required this.periodStart,
    required this.periodEnd,
    required this.onDayTap,
    this.seekerSelectedDates = const {},
    this.singleSelect = false,
    this.isDaySelectable,
  });

  final WorkScheduleSpec spec;
  final List<DateTime> months;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final ValueChanged<DateTime> onDayTap;
  final Set<DateTime> seekerSelectedDates;
  final bool singleSelect;
  final bool Function(DateTime date)? isDaySelectable;

  bool _isSeekerSelected(DateTime date) {
    return seekerSelectedDates.any(
      (d) =>
          d.year == date.year && d.month == date.month && d.day == date.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      primary: false,
      children: [
        const KoreanCalendarWeekdayHeader(),
        const SizedBox(height: 8),
        if (spec.mode == WorkScheduleMode.rotatingShift)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _LegendDot(
                  color: AppColors.primaryLight.withValues(alpha: 0.45),
                  label: '주',
                ),
                _LegendDot(
                  color: Colors.indigo.shade100,
                  label: '야',
                ),
                _LegendDot(
                  color: Colors.grey.shade100,
                  label: '휴',
                ),
                _LegendDot(
                  color: Colors.orange.shade50,
                  label: '비',
                ),
              ],
            ),
          ),
        ...months.map(
          (month) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${month.year}년 ${month.month}월',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                _ScheduleMonthGrid(
                  month: month,
                  spec: spec,
                  periodStart: periodStart,
                  periodEnd: periodEnd,
                  isSeekerSelected: _isSeekerSelected,
                  isDaySelectable: isDaySelectable,
                  onDayTap: onDayTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleMonthGrid extends StatelessWidget {
  const _ScheduleMonthGrid({
    required this.month,
    required this.spec,
    required this.periodStart,
    required this.periodEnd,
    required this.isSeekerSelected,
    required this.onDayTap,
    this.isDaySelectable,
  });

  final DateTime month;
  final WorkScheduleSpec spec;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool Function(DateTime date) isSeekerSelected;
  final bool Function(DateTime date)? isDaySelectable;
  final ValueChanged<DateTime> onDayTap;

  Color? _slotColor(ShiftSlotKind? slot) {
    if (slot == null) return null;
    return switch (slot) {
      ShiftSlotKind.day => AppColors.primaryLight.withValues(alpha: 0.45),
      ShiftSlotKind.night => Colors.indigo.shade100,
      ShiftSlotKind.off => Colors.grey.shade100,
      ShiftSlotKind.standby => Colors.orange.shade50,
    };
  }

  bool _inSelectedRange(DateTime date) {
    if (periodStart == null) return false;
    final d = WorkScheduleCalendarX.dateOnly(date);
    final s = WorkScheduleCalendarX.dateOnly(periodStart!);
    final e = periodEnd == null
        ? s
        : WorkScheduleCalendarX.dateOnly(periodEnd!);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool _isDisabledDay(DateTime date) {
    if (spec.mode != WorkScheduleMode.fixedWeekdays) return false;
    if (!_inSelectedRange(date)) return false;
    return !spec.isWeekdayAllowed(date);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = KoreanCalendarLayout.leadingBlankDays(first);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: leading + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leading) return const SizedBox.shrink();
        final day = index - leading + 1;
        final date = DateTime(month.year, month.month, day);
        final slot = spec.slotOn(date);
        final inRange = _inSelectedRange(date);
        final disabled = _isDisabledDay(date);
        final slotColor = disabled ? null : _slotColor(slot);
        final isWorkSlot =
            slot == ShiftSlotKind.day || slot == ShiftSlotKind.night;
        final isDailyPick = spec.mode == WorkScheduleMode.dailyPick;
        final isWorkDay = isDailyPick && slot == ShiftSlotKind.day;
        final isExcludedCustom = spec.mode == WorkScheduleMode.customDates &&
            inRange &&
            slot == ShiftSlotKind.off;

        Color? fill;
        if (isDailyPick) {
          fill = isWorkDay
              ? AppColors.primaryLight.withValues(alpha: 0.45)
              : Colors.transparent;
        } else if (spec.mode == WorkScheduleMode.fixedWeekdays &&
            inRange &&
            !spec.isWeekdayAllowed(date)) {
          fill = Colors.grey.shade50;
        } else if (disabled) {
          fill = Colors.grey.shade50;
        } else if (slotColor != null && isWorkSlot) {
          fill = slotColor;
        } else if (spec.mode == WorkScheduleMode.fixedWeekdays &&
            inRange &&
            slot == ShiftSlotKind.off) {
          fill = Colors.transparent;
        } else if (inRange && spec.mode != WorkScheduleMode.rotatingShift) {
          fill = isExcludedCustom
              ? Colors.grey.shade100
              : AppColors.primaryLight.withValues(alpha: 0.2);
        }

        final isStartDay = periodStart != null &&
            date.year == periodStart!.year &&
            date.month == periodStart!.month &&
            date.day == periodStart!.day;
        final isEndDay = periodEnd != null &&
            date.year == periodEnd!.year &&
            date.month == periodEnd!.month &&
            date.day == periodEnd!.day;
        final isPeriodEdge =
            !isDailyPick && inRange && (isStartDay || isEndDay);

        final seekerSelected = isSeekerSelected(date);
        final selectable = isDaySelectable?.call(date) ?? true;

        return GestureDetector(
          onTap: selectable ? () => onDayTap(date) : null,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill ?? Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: seekerSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : isPeriodEdge
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.75),
                          width: 1.5,
                        )
                      : inRange &&
                              isWorkSlot &&
                              spec.mode == WorkScheduleMode.fixedWeekdays
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.55),
                            )
                          : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: disabled
                            ? AppColors.textSecondary.withValues(alpha: 0.35)
                            : seekerSelected
                                ? AppColors.primary
                                : isWorkDay
                                    ? AppColors.primary
                                    : slot == ShiftSlotKind.off &&
                                            !isExcludedCustom
                                        ? AppColors.textSecondary
                                            .withValues(alpha: 0.55)
                                        : KoreanCalendarLayout.dayTextColor(date),
                      ),
                    ),
                    if (isWorkDay)
                      Text(
                        '근무',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                      )
                    else if (slot != null &&
                        spec.mode == WorkScheduleMode.rotatingShift &&
                        slot != ShiftSlotKind.off)
                      Text(
                        slot.shortLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: slot == ShiftSlotKind.night
                              ? Colors.indigo
                              : AppColors.primary,
                        ),
                      ),
                    if (isExcludedCustom)
                      Text(
                        '제외',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      )
                    else if (!isDailyPick &&
                        isStartDay &&
                        spec.endDate != null &&
                        !isEndDay)
                      Text(
                        '시작',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                      )
                    else if (!isDailyPick && isEndDay && !isStartDay)
                      Text(
                        '종료',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
                if (seekerSelected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.95),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
