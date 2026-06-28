import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/calendar/korean_public_holidays.dart';
import 'package:map/core/constants/app_colors.dart';

/// 일요일 시작 달력 — 네이버·국내 포털 달력 스타일 (일·공휴일 빨강, 토 파랑)
abstract final class KoreanCalendarLayout {
  static const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

  /// [DateTime.weekday] 기준 leading blank (일=7 → 0)
  static int leadingBlankDays(DateTime firstOfMonth) =>
      firstOfMonth.weekday % 7;

  static Color weekdayHeaderColor(int columnIndex) {
    if (columnIndex == 0) return const Color(0xFFE53935);
    if (columnIndex == 6) return const Color(0xFF1E88E5);
    return AppColors.textSecondary.withValues(alpha: 0.85);
  }

  static Color dayTextColor(
    DateTime date, {
    bool disabled = false,
    Color? fallback,
  }) {
    if (disabled) {
      return AppColors.textSecondary.withValues(alpha: 0.35);
    }
    if (date.weekday == DateTime.sunday ||
        KoreanPublicHolidays.isHoliday(date)) {
      return const Color(0xFFE53935);
    }
    if (date.weekday == DateTime.saturday) {
      return const Color(0xFF1E88E5);
    }
    return fallback ?? AppColors.textPrimary;
  }

  static List<DateTime> monthRange({
    required DateTime from,
    required DateTime to,
  }) {
    final start = DateTime(from.year, from.month);
    final end = DateTime(to.year, to.month);
    final months = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }
}

/// 공통 요일 헤더 행
class KoreanCalendarWeekdayHeader extends StatelessWidget {
  const KoreanCalendarWeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(KoreanCalendarLayout.weekdayLabels.length, (i) {
        return Expanded(
          child: Center(
            child: Text(
              KoreanCalendarLayout.weekdayLabels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KoreanCalendarLayout.weekdayHeaderColor(i),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 급여지급일 등 단일 날짜 선택 — 근무일정과 동일한 세로 달력
Future<DateTime?> showKoreanDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '날짜 선택',
}) {
  final safeInitial = _clampDate(initialDate, firstDate, lastDate);
  return showAdaptiveSheet<DateTime>(
    context: context,
    builder: (context) => _KoreanDatePickerSheet(
      title: title,
      initialDate: safeInitial,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime(lastDate.year, lastDate.month, lastDate.day),
    ),
  );
}

DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
  final d = DateTime(value.year, value.month, value.day);
  final lo = DateTime(min.year, min.month, min.day);
  final hi = DateTime(max.year, max.month, max.day);
  if (d.isBefore(lo)) return lo;
  if (d.isAfter(hi)) return hi;
  return d;
}

class _KoreanDatePickerSheet extends StatefulWidget {
  const _KoreanDatePickerSheet({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_KoreanDatePickerSheet> createState() => _KoreanDatePickerSheetState();
}

class _KoreanDatePickerSheetState extends State<_KoreanDatePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  bool _isSelectable(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);
  }

  @override
  Widget build(BuildContext context) {
    final months = KoreanCalendarLayout.monthRange(
      from: widget.firstDate,
      to: widget.lastDate,
    );
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selected.year}년 ${_selected.month}월 ${_selected.day}일',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          const KoreanCalendarWeekdayHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                return Padding(
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
                      _SimpleMonthGrid(
                        month: month,
                        selected: _selected,
                        isSelectable: _isSelectable,
                        onDayTap: (date) {
                          setState(() => _selected = date);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '확인',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleMonthGrid extends StatelessWidget {
  const _SimpleMonthGrid({
    required this.month,
    required this.selected,
    required this.isSelectable,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime selected;
  final bool Function(DateTime date) isSelectable;
  final ValueChanged<DateTime> onDayTap;

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
        final enabled = isSelectable(date);
        final isSelected = selected.year == date.year &&
            selected.month == date.month &&
            selected.day == date.day;

        return GestureDetector(
          onTap: enabled ? () => onDayTap(date) : null,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryLight.withValues(alpha: 0.45)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.75),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: KoreanCalendarLayout.dayTextColor(
                  date,
                  disabled: !enabled,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
