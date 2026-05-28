import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/scroll_time_picker.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

/// 근무 일정 선택 — 요일 고정 / 교대 순환 / 날짜 맞춤 / 일용직 날짜 선택
class WorkScheduleSelectorField extends StatefulWidget {
  const WorkScheduleSelectorField({
    super.key,
    required this.controller,
    this.dailyOnly = false,
  });

  final TextEditingController controller;
  /// 일용직 — 탭 없이 달력에서 근무일만 하루씩 선택
  final bool dailyOnly;

  @override
  State<WorkScheduleSelectorField> createState() =>
      _WorkScheduleSelectorFieldState();
}

class _WorkScheduleSelectorFieldState extends State<WorkScheduleSelectorField> {
  WorkScheduleSpec _spec = WorkScheduleSpec();

  static const _monFri = {0, 1, 2, 3, 4};
  static const _monSat = {0, 1, 2, 3, 4, 5};
  static const _endBeforeStartMsg =
      '근무 종료일은 시작일보다 앞설 수 없습니다.';

  @override
  void initState() {
    super.initState();
    _loadFromController();
    widget.controller.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    _loadFromController();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(WorkScheduleSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dailyOnly != oldWidget.dailyOnly) {
      if (widget.dailyOnly) {
        final parsed = WorkScheduleCodec.tryParse(widget.controller.text);
        if (parsed == null || parsed.mode != WorkScheduleMode.dailyPick) {
          widget.controller.clear();
        }
        _loadFromController(forceDailyOnly: true);
      } else {
        final parsed = WorkScheduleCodec.tryParse(widget.controller.text);
        if (parsed?.mode == WorkScheduleMode.dailyPick) {
          widget.controller.clear();
        }
        _loadFromController(forceDailyOnly: false);
      }
      if (mounted) setState(() {});
    }
  }

  WorkScheduleSpec _emptyDailySpec() => WorkScheduleSpec(
        mode: WorkScheduleMode.dailyPick,
        dayStart: _spec.dayStart,
        dayEnd: _spec.dayEnd,
      );

  void _loadFromController({bool? forceDailyOnly}) {
    final dailyOnly = forceDailyOnly ?? widget.dailyOnly;
    final parsed = WorkScheduleCodec.tryParse(widget.controller.text);
    if (dailyOnly) {
      if (parsed != null && parsed.mode == WorkScheduleMode.dailyPick) {
        _spec = parsed;
      } else {
        _spec = _emptyDailySpec();
      }
      return;
    }
    if (parsed != null && parsed.mode != WorkScheduleMode.dailyPick) {
      _spec = parsed;
    } else if (parsed == null) {
      _spec = WorkScheduleSpec();
    } else {
      _spec = WorkScheduleSpec();
    }
  }

  void _commit() {
    if (_spec.mode == WorkScheduleMode.dailyPick) {
      _spec = _spec.withDerivedDailyBounds();
    }
    widget.controller.text = WorkScheduleCodec.encode(_spec);
    setState(() {});
  }

  String _fieldLabel() {
    final committed = widget.controller.text.trim();
    if (committed.isNotEmpty) return committed;
    return widget.dailyOnly ? '근무일 선택' : '근무 일정 선택';
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _padTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _hasCompletePeriod() =>
      _spec.startDate != null && _spec.endDate != null;

  (DateTime?, DateTime?) _activePeriodBounds() {
    if (_spec.startDate == null) return (null, null);
    if (_spec.endDate == null) {
      final s = _dateOnly(_spec.startDate!);
      return (s, s);
    }
    return (_dateOnly(_spec.startDate!), _dateOnly(_spec.endDate!));
  }

  void _showPeriodError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_endBeforeStartMsg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isInActivePeriod(DateTime day) {
    final (start, end) = _activePeriodBounds();
    if (start == null || end == null) return false;
    final d = _dateOnly(day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  List<DateTime> _monthsToShow() {
    final now = DateTime.now();
    var minMonth = DateTime(now.year, now.month);
    var maxMonth = DateTime(now.year, now.month);

    for (final date in [
      _spec.startDate,
      _spec.endDate,
      ..._spec.selectedWorkDates,
    ]) {
      if (date == null) continue;
      final m = DateTime(date.year, date.month);
      if (m.isBefore(minMonth)) minMonth = m;
      if (m.isAfter(maxMonth)) maxMonth = m;
    }

    final rangeStart = DateTime(minMonth.year, minMonth.month - 1);
    var rangeEnd = DateTime(maxMonth.year, maxMonth.month + 2);
    final minSpanEnd = DateTime(rangeStart.year, rangeStart.month + 14);
    if (rangeEnd.isBefore(minSpanEnd)) rangeEnd = minSpanEnd;

    final months = <DateTime>[];
    var cursor = rangeStart;
    while (!cursor.isAfter(rangeEnd)) {
      months.add(DateTime(cursor.year, cursor.month));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  void _onModeChanged(WorkScheduleMode mode) {
    setState(() {
      _spec = _spec.copyWith(
        mode: mode,
        customExcludedDates:
            mode == WorkScheduleMode.customDates ? {} : _spec.customExcludedDates,
      );
    });
  }

  void _setPeriod(DateTime start, DateTime end) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    _spec = _spec
        .copyWith(startDate: s, endDate: e)
        .trimExcludedDatesToRange();
  }

  void _toggleExclusion(DateTime day) {
    final normalized = _dateOnly(day);
    if (_spec.startDate == null || _spec.endDate == null) return;
    final s = _dateOnly(_spec.startDate!);
    final e = _dateOnly(_spec.endDate!);
    if (normalized.isBefore(s) || normalized.isAfter(e)) return;

    final excluded = Set<DateTime>.from(_spec.customExcludedDates);
    final exists = excluded.any(
      (d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day,
    );
    if (exists) {
      excluded.removeWhere(
        (d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day,
      );
    } else {
      excluded.add(normalized);
    }
    _spec = _spec.copyWith(customExcludedDates: excluded);
  }

  void _toggleDailyWorkDay(DateTime day) {
    final normalized = _dateOnly(day);
    final dates = Set<DateTime>.from(_spec.selectedWorkDates);
    final exists = dates.any(
      (d) =>
          d.year == normalized.year &&
          d.month == normalized.month &&
          d.day == normalized.day,
    );
    if (exists) {
      dates.removeWhere(
        (d) =>
            d.year == normalized.year &&
            d.month == normalized.month &&
            d.day == normalized.day,
      );
    } else {
      dates.add(normalized);
    }
    _spec = _spec.copyWith(selectedWorkDates: dates).withDerivedDailyBounds();
  }

  void _selectDay(BuildContext context, DateTime day) {
    final normalized = _dateOnly(day);

    if (_spec.mode == WorkScheduleMode.dailyPick) {
      _toggleDailyWorkDay(normalized);
      return;
    }

    if (_spec.mode == WorkScheduleMode.customDates) {
      if (_hasCompletePeriod() && _isInActivePeriod(normalized)) {
        _toggleExclusion(normalized);
        return;
      }
      _applyPeriodTap(context, normalized, clearExclusions: true);
      return;
    }

    _applyPeriodTap(context, normalized, clearExclusions: false);
  }

  /// 1탭=시작일, 2탭=종료일(같은 날 가능), 3탭~=새 시작일
  void _applyPeriodTap(
    BuildContext context,
    DateTime normalized, {
    required bool clearExclusions,
  }) {
    if (_spec.startDate == null) {
      _spec = _spec.copyWith(
        startDate: normalized,
        clearEndDate: true,
        customExcludedDates: clearExclusions ? {} : _spec.customExcludedDates,
      );
      return;
    }

    if (_spec.endDate == null) {
      final start = _dateOnly(_spec.startDate!);
      if (normalized.isBefore(start)) {
        _showPeriodError(context);
        return;
      }
      _setPeriod(start, normalized);
      if (clearExclusions) {
        _spec = _spec.copyWith(customExcludedDates: {});
      }
      return;
    }

    _spec = _spec.copyWith(
      startDate: normalized,
      clearEndDate: true,
      customExcludedDates: clearExclusions ? {} : _spec.customExcludedDates,
    );
  }

  Future<void> _pickTime({
    required bool isStart,
    required bool isNight,
  }) async {
    final initial = isNight
        ? (isStart ? _spec.nightStart : _spec.nightEnd)
        : (isStart ? _spec.dayStart : _spec.dayEnd);
    final picked = await showScrollTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isNight) {
        _spec = _spec.copyWith(
          nightStart: isStart ? picked : _spec.nightStart,
          nightEnd: isStart ? _spec.nightEnd : picked,
        );
      } else {
        _spec = _spec.copyWith(
          dayStart: isStart ? picked : _spec.dayStart,
          dayEnd: isStart ? _spec.dayEnd : picked,
        );
      }
    });
  }

  void _appendCustomCycleSlot(ShiftSlotKind slot) {
    if (_spec.customCycle.length >= 14) return;
    setState(() {
      _spec = _spec.copyWith(
        customCycle: [..._spec.customCycle, slot],
        cycleStartIndex: 0,
      );
    });
  }

  void _popCustomCycleSlot() {
    if (_spec.customCycle.length <= 2) return;
    setState(() {
      final next = List<ShiftSlotKind>.from(_spec.customCycle)..removeLast();
      _spec = _spec.copyWith(
        customCycle: next,
        cycleStartIndex: 0,
      );
    });
  }

  Future<void> _openSheet() async {
    if (widget.dailyOnly && _spec.mode != WorkScheduleMode.dailyPick) {
      _spec = _emptyDailySpec();
    }

    final calendarScrollController = ScrollController();
    final calendarMonths = _monthsToShow();

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

            final preview = WorkScheduleCodec.encode(_spec);
            final cycle = _spec.rotatingCycle;
            final isCustomPreset =
                _spec.rotatingPresetId == RotatingShiftPreset.customDirect.id;
            final isDaily = _spec.mode == WorkScheduleMode.dailyPick;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                    const SizedBox(height: 16),
                    Text(
                      isDaily ? '근무일 선택' : '근무 일정 설정',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isDaily
                          ? '달력에서 근무일을 하루씩 탭해 선택·해제하세요.'
                          : '요일 고정·교대·비정기 등 현장 패턴을 선택하세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isDaily) ...[
                      SegmentedButton<WorkScheduleMode>(
                        segments: const [
                          ButtonSegment(
                            value: WorkScheduleMode.fixedWeekdays,
                            label: Text('요일 고정'),
                          ),
                          ButtonSegment(
                            value: WorkScheduleMode.rotatingShift,
                            label: Text('교대 순환'),
                          ),
                          ButtonSegment(
                            value: WorkScheduleMode.customDates,
                            label: Text('날짜 맞춤'),
                          ),
                        ],
                        selected: {_spec.mode},
                        onSelectionChanged: (selection) {
                          _onModeChanged(selection.first);
                          refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isDaily && _spec.mode == WorkScheduleMode.fixedWeekdays) ...[
                      const Text(
                        '근무 요일',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (index) {
                          final selected = _spec.weekdays.contains(index);
                          return FilterChip(
                            label: Text(WorkScheduleSpec.weekdayLabels[index]),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                final days = Set<int>.from(_spec.weekdays);
                                if (value) {
                                  days.add(index);
                                } else if (days.length > 1) {
                                  days.remove(index);
                                }
                                _spec = _spec.copyWith(weekdays: days);
                              });
                              refresh();
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('월~금'),
                            selected: _spec.weekdays.containsAll(_monFri) &&
                                _spec.weekdays.length == _monFri.length,
                            onSelected: (_) {
                              setState(() {
                                _spec = _spec.copyWith(weekdays: _monFri);
                              });
                              refresh();
                            },
                          ),
                          FilterChip(
                            label: const Text('월~토'),
                            selected: _spec.weekdays.containsAll(_monSat) &&
                                _spec.weekdays.length == _monSat.length,
                            onSelected: (_) {
                              setState(() {
                                _spec = _spec.copyWith(weekdays: _monSat);
                              });
                              refresh();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '선택한 요일만 근무일로 표시됩니다. 달력을 아래로 스크롤해 월을 넘기고, 기간 안의 토·일은 휴무로 보입니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    if (!isDaily && _spec.mode == WorkScheduleMode.rotatingShift) ...[
                      const Text(
                        '교대 패턴',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...RotatingShiftPreset.all.map((p) {
                        final selected = _spec.rotatingPresetId == p.id;
                        final subtitle = p.id == RotatingShiftPreset.customDirect.id
                            ? p.subtitle
                            : '${p.subtitle} · ${p.patternLabel}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: selected
                                ? AppColors.primaryLight.withValues(alpha: 0.35)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _spec = _spec.copyWith(
                                    rotatingPresetId: p.id,
                                    cycleStartIndex: 0,
                                  );
                                });
                                refresh();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.searchBarBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(Icons.check_circle,
                                          color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (isCustomPreset) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '패턴 직접 구성 (탭하여 추가)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final slot in ShiftSlotKind.values)
                              ActionChip(
                                label: Text('+ ${slot.label}'),
                                onPressed: () {
                                  _appendCustomCycleSlot(slot);
                                  refresh();
                                },
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.undo, size: 16),
                              label: const Text('한 칸 삭제'),
                              onPressed: () {
                                _popCustomCycleSlot();
                                refresh();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '현재: ${_spec.customCycle.map((s) => s.shortLabel).join(' · ')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                      if (cycle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '시작일 첫 근무 (조·교대에 맞게 선택)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(cycle.length, (i) {
                            final slot = cycle[i];
                            return ChoiceChip(
                              label: Text('${i + 1}일차 ${slot.label}'),
                              selected: _spec.cycleStartIndex == i,
                              onSelected: (_) {
                                setState(() {
                                  _spec = _spec.copyWith(cycleStartIndex: i);
                                });
                                refresh();
                              },
                            );
                          }),
                        ),
                      ],
                    ],
                    if (!isDaily && _spec.mode == WorkScheduleMode.customDates) ...[
                      Text(
                        '시작일·종료일을 탭한 뒤, 근무 제외일만 탭해 끄세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 12),
                    if (!isDaily) ...[
                      const Text(
                        '근무 기간',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '달력은 위아래 스크롤만 사용합니다. 첫 탭=시작일, 둘째 탭=종료일(같은 날 가능).',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                      SizedBox(
                        height: 22,
                        child: _spec.startDate != null && _spec.endDate == null
                            ? Text(
                                '근무 종료일을 선택하세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.9),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      Text(
                        '선택 ${_spec.selectedWorkDates.length}일',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: (MediaQuery.of(context).size.height * 0.38)
                          .clamp(280.0, 420.0),
                      child: _VerticalScheduleCalendar(
                        key: const PageStorageKey('work_schedule_calendar'),
                        scrollController: calendarScrollController,
                        months: calendarMonths,
                        spec: _spec,
                        periodStart: _activePeriodBounds().$1,
                        periodEnd: _activePeriodBounds().$2,
                        onDayTap: (day) {
                          _selectDay(context, day);
                          refresh();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
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
                              await _pickTime(isStart: true, isNight: false);
                              refresh();
                            },
                            icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                            label: Text(
                              '주 ${_padTime(_spec.dayStart)}~${_padTime(_spec.dayEnd)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isDaily && _spec.mode == WorkScheduleMode.rotatingShift) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _pickTime(isStart: true, isNight: true);
                                refresh();
                              },
                              icon: const Icon(Icons.nightlight_round,
                                  size: 18),
                              label: Text(
                                '야 ${_padTime(_spec.nightStart)}~${_padTime(_spec.nightEnd)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primary.withValues(alpha: 0.95),
                        ),
                      )
                    else
                      Text(
                        isDaily ? '근무일과 시간을 선택하세요' : '기간과 패턴을 선택하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    if (_spec.isComplete && _spec.countWorkDays() > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '기간 내 근무 ${_spec.countWorkDays()}일',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _spec.isComplete
                          ? () {
                              if (!isDaily &&
                                  _spec.endDate == null &&
                                  _spec.startDate != null) {
                                _spec =
                                    _spec.copyWith(endDate: _spec.startDate);
                              }
                              _commit();
                              Navigator.of(context).pop();
                            }
                          : null,
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
    calendarScrollController.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final label = _fieldLabel();
    final hasValue = widget.controller.text.trim().isNotEmpty;

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
              color: hasValue
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.searchBarBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.dailyOnly
                    ? Icons.calendar_month_rounded
                    : Icons.event_repeat_rounded,
                color: hasValue
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        hasValue ? FontWeight.w600 : FontWeight.w400,
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

class _VerticalScheduleCalendar extends StatelessWidget {
  const _VerticalScheduleCalendar({
    super.key,
    required this.scrollController,
    required this.months,
    required this.spec,
    required this.periodStart,
    required this.periodEnd,
    required this.onDayTap,
  });

  final ScrollController scrollController;
  final List<DateTime> months;
  final WorkScheduleSpec spec;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return ListView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      primary: false,
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
    required this.onDayTap,
  });

  final DateTime month;
  final WorkScheduleSpec spec;
  final DateTime? periodStart;
  final DateTime? periodEnd;
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
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(periodStart!.year, periodStart!.month, periodStart!.day);
    final e = periodEnd == null
        ? s
        : DateTime(periodEnd!.year, periodEnd!.month, periodEnd!.day);
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
    final leading = (first.weekday + 6) % 7;

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

        return GestureDetector(
          onTap: () => onDayTap(date),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill ?? Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isPeriodEdge
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: disabled
                        ? AppColors.textSecondary.withValues(alpha: 0.35)
                        : isWorkDay
                            ? AppColors.primary
                            : slot == ShiftSlotKind.off && !isExcludedCustom
                                ? AppColors.textSecondary.withValues(alpha: 0.55)
                                : AppColors.textPrimary,
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
                else if (!isDailyPick && isStartDay && spec.endDate != null && !isEndDay)
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
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
