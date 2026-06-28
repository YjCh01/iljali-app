import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/scroll_time_picker.dart';

/// 근무 일정 — 요일 선택 + 시작/종료 시간 (달력·시계 UI)
class WorkSchedulePickerField extends StatefulWidget {
  const WorkSchedulePickerField({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  static const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  State<WorkSchedulePickerField> createState() =>
      _WorkSchedulePickerFieldState();
}

class _WorkSchedulePickerFieldState extends State<WorkSchedulePickerField> {
  final Set<int> _weekdays = {0, 1, 2, 3, 4};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);
  DateTime? _startDate;

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
    if (!_matchesController()) {
      _parseExisting(widget.controller.text);
      if (mounted) setState(() {});
    }
  }

  bool _matchesController() => widget.controller.text == _formatSchedule();

  void _parseExisting(String raw) {
    if (raw.trim().isEmpty) return;
    final timeMatch = RegExp(
      r'(\d{1,2}):(\d{2})\s*[~\-–—]\s*(\d{1,2}):(\d{2})',
    ).firstMatch(raw);
    if (timeMatch != null) {
      _start = TimeOfDay(
        hour: int.parse(timeMatch.group(1)!),
        minute: int.parse(timeMatch.group(2)!),
      );
      _end = TimeOfDay(
        hour: int.parse(timeMatch.group(3)!),
        minute: int.parse(timeMatch.group(4)!),
      );
    }
    _weekdays.clear();
    for (var i = 0; i < WorkSchedulePickerField.weekdayLabels.length; i++) {
      if (raw.contains(WorkSchedulePickerField.weekdayLabels[i])) {
        _weekdays.add(i);
      }
    }
    if (_weekdays.isEmpty) _weekdays.addAll([0, 1, 2, 3, 4]);
    final dateMatch = RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})')
        .firstMatch(raw);
    if (dateMatch != null) {
      _startDate = DateTime(
        int.parse(dateMatch.group(1)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(3)!),
      );
    }
  }

  String _formatSchedule() {
    final days = WorkSchedulePickerField.weekdayLabels
        .asMap()
        .entries
        .where((e) => _weekdays.contains(e.key))
        .map((e) => e.value)
        .join('');
    final dayPart = days.isEmpty ? '주 5일' : '주 ${days.length}일($days)';
    final timePart =
        '${_padTime(_start)}~${_padTime(_end)}';
    if (_startDate != null) {
      final d = _startDate!;
      return '$dayPart · $timePart · ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}부터';
    }
    return '$dayPart · $timePart';
  }

  String _padTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _apply() {
    widget.controller.text = _formatSchedule();
    setState(() {});
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '근무 시작일',
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _apply();
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showScrollTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _apply();
    });
  }

  Future<void> _openSheet() async {
    await showAdaptiveSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.searchBarBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '근무 일정 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '근무 요일',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      WorkSchedulePickerField.weekdayLabels.length,
                      (index) {
                        final selected = _weekdays.contains(index);
                        return FilterChip(
                          label: Text(WorkSchedulePickerField.weekdayLabels[index]),
                          selected: selected,
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                _weekdays.add(index);
                              } else if (_weekdays.length > 1) {
                                _weekdays.remove(index);
                              }
                              _apply();
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '근무 시간',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _pickTime(isStart: true);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text('시작 ${_padTime(_start)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _pickTime(isStart: false);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.schedule_outlined, size: 18),
                          label: Text('종료 ${_padTime(_end)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _pickStartDate();
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      _startDate == null
                          ? '근무 시작일 선택 (선택)'
                          : '시작일 ${_startDate!.year}.${_startDate!.month}.${_startDate!.day}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      _apply();
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.controller.text.trim().isEmpty
        ? '요일·시간·시작일 선택'
        : widget.controller.text;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openSheet,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.controller.text.isNotEmpty
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.searchBarBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                color: widget.controller.text.isNotEmpty
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: widget.controller.text.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: widget.controller.text.isNotEmpty
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
