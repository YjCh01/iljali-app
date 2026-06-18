import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
/// 달력 날짜별 출근 상태 점
enum AttendanceDayMarker {
  none,
  scheduled,
  checkedIn,
  pending,
  absent,
}

class AttendanceCalendarDayEntry {
  const AttendanceCalendarDayEntry({
    required this.date,
    this.marker = AttendanceDayMarker.none,
    this.count = 0,
  });

  final DateTime date;
  final AttendanceDayMarker marker;
  final int count;
}

/// 근태 탭 공통 월간 달력
class AttendanceMonthCalendar extends StatefulWidget {
  const AttendanceMonthCalendar({
    super.key,
    required this.entries,
    required this.selectedDay,
    required this.onDaySelected,
    this.headerTrailing,
    this.onMonthChanged,
  });

  final List<AttendanceCalendarDayEntry> entries;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final Widget? headerTrailing;
  final ValueChanged<DateTime>? onMonthChanged;

  @override
  State<AttendanceMonthCalendar> createState() =>
      _AttendanceMonthCalendarState();
}

class _AttendanceMonthCalendarState extends State<AttendanceMonthCalendar> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
    );
  }

  @override
  void didUpdateWidget(covariant AttendanceMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDay.year != _focusedMonth.year ||
        widget.selectedDay.month != _focusedMonth.month) {
      _focusedMonth = DateTime(
        widget.selectedDay.year,
        widget.selectedDay.month,
      );
    }
  }

  AttendanceDayMarker _markerFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final entry in widget.entries) {
      final e = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (e == normalized) return entry.marker;
    }
    return AttendanceDayMarker.none;
  }

  int _countFor(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final entry in widget.entries) {
      final e = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (e == normalized) return entry.count;
    }
    return 0;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
    widget.onMonthChanged?.call(_focusedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_focusedMonth.year}년 ${_focusedMonth.month}월';
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final today = DateTime.now();
    final selected = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.headerTrailing != null) widget.headerTrailing!,
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: label == '일'
                              ? Colors.red.shade400
                              : label == '토'
                                  ? Colors.blue.shade400
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final dayNum = index - startWeekday + 1;
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNum,
              );
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = date == selected;
              final marker = _markerFor(date);
              final count = _countFor(date);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onDaySelected(date),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : isToday
                              ? AppColors.primaryLight.withValues(alpha: 0.12)
                              : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _DayDot(marker: marker, count: count),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: const [
              _LegendDot(color: Color(0xFF7C5CFC), label: '예정'),
              _LegendDot(color: Color(0xFF2E7D32), label: '출근'),
              _LegendDot(color: Color(0xFFF9A825), label: '대기'),
              _LegendDot(color: Color(0xFFC62828), label: '결근'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.marker, required this.count});

  final AttendanceDayMarker marker;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (marker == AttendanceDayMarker.none && count <= 0) {
      return const SizedBox(height: 6, width: 6);
    }

    final color = switch (marker) {
      AttendanceDayMarker.checkedIn => const Color(0xFF2E7D32),
      AttendanceDayMarker.pending => const Color(0xFFF9A825),
      AttendanceDayMarker.absent => const Color(0xFFC62828),
      AttendanceDayMarker.scheduled => AppColors.primary,
      AttendanceDayMarker.none => AppColors.textSecondary,
    };

    if (count > 1) {
      return Text(
        '$count',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      );
    }

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
