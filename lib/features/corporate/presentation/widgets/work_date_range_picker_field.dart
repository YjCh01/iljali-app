import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/scroll_time_picker.dart';

/// 근무일·시간 — 달력 탭·드래그로 기간 선택 + 시작/종료 시각
class WorkDateRangePickerField extends StatefulWidget {
  const WorkDateRangePickerField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  State<WorkDateRangePickerField> createState() =>
      _WorkDateRangePickerFieldState();
}

class _WorkDateRangePickerFieldState extends State<WorkDateRangePickerField> {
  DateTime? _start;
  DateTime? _end;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _dragAnchor;

  static final _timeRangePattern = RegExp(
    r'(\d{1,2}):(\d{2})\s*[~\-–—]\s*(\d{1,2}):(\d{2})',
  );

  @override
  void initState() {
    super.initState();
    _parseExisting(widget.controller.text);
    widget.controller.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    if (widget.controller.text != _formatRange()) {
      _parseExisting(widget.controller.text);
      if (mounted) setState(() {});
    }
  }

  void _parseExisting(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    final timeMatch = _timeRangePattern.firstMatch(trimmed);
    if (timeMatch != null) {
      _startTime = TimeOfDay(
        hour: int.parse(timeMatch.group(1)!),
        minute: int.parse(timeMatch.group(2)!),
      );
      _endTime = TimeOfDay(
        hour: int.parse(timeMatch.group(3)!),
        minute: int.parse(timeMatch.group(4)!),
      );
    }

    final match = RegExp(
      r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})\s*[~\-–—]\s*(\d{4})[./-](\d{1,2})[./-](\d{1,2})',
    ).firstMatch(trimmed);
    if (match == null) return;
    _start = DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    _end = DateTime(
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
    _visibleMonth = DateTime(_start!.year, _start!.month);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatDateRange() {
    if (_start == null) return '';
    final s = _formatDate(_start!);
    if (_end == null) return '$s ~ 종료일 선택';
    return '$s ~ ${_formatDate(_end!)}';
  }

  String _formatTimeRange() =>
      '${_padTime(_startTime)}~${_padTime(_endTime)}';

  String _formatRange() {
    final dates = _formatDateRange();
    if (dates.isEmpty) return '';
    return '$dates · ${_formatTimeRange()}';
  }

  String _fieldLabel() {
    final committed = widget.controller.text.trim();
    if (committed.isNotEmpty) return committed;
    if (_start == null) return '근무일·시간 선택';
    return _formatRange();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _padTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showScrollTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _commit() {
    widget.controller.text = _formatRange();
    setState(() {});
  }

  void _selectDay(DateTime day) {
    final normalized = _dateOnly(day);
    if (_start == null || (_start != null && _end != null)) {
      _start = normalized;
      _end = null;
    } else {
      if (normalized.isBefore(_start!)) {
        _end = _start;
        _start = normalized;
      } else {
        _end = normalized;
      }
      _commit();
    }
    setState(() {});
  }

  void _extendDrag(DateTime day) {
    if (_dragAnchor == null) return;
    final anchor = _dateOnly(_dragAnchor!);
    final current = _dateOnly(day);
    if (current.isBefore(anchor)) {
      _start = current;
      _end = anchor;
    } else {
      _start = anchor;
      _end = current;
    }
    setState(() {});
  }

  Future<void> _openPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refresh() => setSheetState(() {});

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 16),
                    const Text(
                      '근무일·시간 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '날짜를 탭하거나 드래그해 기간을 설정하고, 근무 시간을 지정하세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                            );
                            refresh();
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          '${_visibleMonth.year}년 ${_visibleMonth.month}월',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            );
                            refresh();
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    _MonthGrid(
                      month: _visibleMonth,
                      start: _start,
                      end: _end,
                      onDayTap: (day) {
                        _selectDay(day);
                        refresh();
                      },
                      onDayDragStart: (day) {
                        _dragAnchor = _dateOnly(day);
                        _start = _dragAnchor;
                        _end = _dragAnchor;
                        refresh();
                      },
                      onDayDragUpdate: (day) {
                        _extendDrag(day);
                        refresh();
                      },
                      onDayDragEnd: () {
                        _dragAnchor = null;
                        _commit();
                        refresh();
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '근무 시간',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _pickTime(isStart: true);
                              refresh();
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 18),
                            label: Text('시작 ${_padTime(_startTime)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _pickTime(isStart: false);
                              refresh();
                            },
                            icon: const Icon(Icons.schedule_outlined, size: 18),
                            label: Text('종료 ${_padTime(_endTime)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatDateRange().isEmpty
                          ? '선택된 기간 없음'
                          : _formatRange(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _start == null
                          ? null
                          : () {
                              if (_end == null) _end = _start;
                              _commit();
                              Navigator.of(context).pop();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('적용'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final label = _fieldLabel();
    final hasValue = widget.controller.text.trim().isNotEmpty ||
        _start != null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openPicker,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasValue
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.searchBarBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                color: hasValue
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: hasValue
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: hasValue
                        ? AppColors.textPrimary
                        : AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatefulWidget {
  const _MonthGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.onDayTap,
    required this.onDayDragStart,
    required this.onDayDragUpdate,
    required this.onDayDragEnd,
  });

  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayDragStart;
  final ValueChanged<DateTime> onDayDragUpdate;
  final VoidCallback onDayDragEnd;

  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<_MonthGrid> {
  final _gridKey = GlobalKey();

  DateTime? _dateAtGlobal(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      return null;
    }
    final first = DateTime(widget.month.year, widget.month.month, 1);
    final daysInMonth = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    const crossCount = 7;
    const mainSpacing = 6.0;
    const crossSpacing = 6.0;
    final rowCount = ((leading + daysInMonth) / crossCount).ceil();
    final cellW =
        (box.size.width - crossSpacing * (crossCount - 1)) / crossCount;
    final cellH =
        (box.size.height - mainSpacing * (rowCount - 1)) / rowCount;
    final col = (local.dx / (cellW + crossSpacing)).floor().clamp(0, 6);
    final row = (local.dy / (cellH + mainSpacing)).floor();
    final cellIndex = row * crossCount + col;
    if (cellIndex < leading || cellIndex >= leading + daysInMonth) {
      return null;
    }
    final dragDay = cellIndex - leading + 1;
    return DateTime(widget.month.year, widget.month.month, dragDay);
  }

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final first = DateTime(widget.month.year, widget.month.month, 1);
    final daysInMonth = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          key: _gridKey,
          onPanStart: (details) {
            final date = _dateAtGlobal(details.globalPosition);
            if (date != null) widget.onDayDragStart(date);
          },
          onPanUpdate: (details) {
            final date = _dateAtGlobal(details.globalPosition);
            if (date != null) widget.onDayDragUpdate(date);
          },
          onPanEnd: (_) => widget.onDayDragEnd(),
          child: GridView.builder(
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
            final date = DateTime(widget.month.year, widget.month.month, day);
            final inRange = _isInRange(date);
            final isEdge = _isEdge(date);

            return GestureDetector(
              onTap: () => widget.onDayTap(date),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: inRange
                      ? AppColors.primaryLight.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isEdge
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isEdge ? FontWeight.w800 : FontWeight.w600,
                    color: inRange
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
        ),
      ],
    );
  }

  bool _isInRange(DateTime date) {
    if (widget.start == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(widget.start!.year, widget.start!.month, widget.start!.day);
    if (widget.end == null) return d == s;
    final e = DateTime(widget.end!.year, widget.end!.month, widget.end!.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool _isEdge(DateTime date) {
    if (widget.start == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(widget.start!.year, widget.start!.month, widget.start!.day);
    if (widget.end == null) return d == s;
    final e = DateTime(widget.end!.year, widget.end!.month, widget.end!.day);
    return d == s || d == e;
  }
}
