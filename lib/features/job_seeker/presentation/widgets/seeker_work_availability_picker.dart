import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';

/// 근무 가능 스케줄 — 프리셋 칩 + 요일별 슬롯 pill + 추가 bottom sheet
class SeekerWorkAvailabilityPicker extends StatelessWidget {
  const SeekerWorkAvailabilityPicker({
    super.key,
    required this.availability,
    required this.onChanged,
  });

  final SeekerWorkAvailability availability;
  final ValueChanged<SeekerWorkAvailability> onChanged;

  static const _presets = [
    _Preset(
      label: '평일 오전',
      slots: [
        SeekerAvailabilitySlot(weekday: 0, startMinutes: 360, endMinutes: 720),
        SeekerAvailabilitySlot(weekday: 1, startMinutes: 360, endMinutes: 720),
        SeekerAvailabilitySlot(weekday: 2, startMinutes: 360, endMinutes: 720),
        SeekerAvailabilitySlot(weekday: 3, startMinutes: 360, endMinutes: 720),
        SeekerAvailabilitySlot(weekday: 4, startMinutes: 360, endMinutes: 720),
      ],
    ),
    _Preset(
      label: '평일 오후',
      slots: [
        SeekerAvailabilitySlot(weekday: 0, startMinutes: 720, endMinutes: 1080),
        SeekerAvailabilitySlot(weekday: 1, startMinutes: 720, endMinutes: 1080),
        SeekerAvailabilitySlot(weekday: 2, startMinutes: 720, endMinutes: 1080),
        SeekerAvailabilitySlot(weekday: 3, startMinutes: 720, endMinutes: 1080),
        SeekerAvailabilitySlot(weekday: 4, startMinutes: 720, endMinutes: 1080),
      ],
    ),
    _Preset(
      label: '주말',
      slots: [
        SeekerAvailabilitySlot(weekday: 5, anyTime: true),
        SeekerAvailabilitySlot(weekday: 6, anyTime: true),
      ],
    ),
    _Preset(
      label: '시간 무관',
      slots: [
        SeekerAvailabilitySlot(weekday: 0, anyTime: true),
        SeekerAvailabilitySlot(weekday: 1, anyTime: true),
        SeekerAvailabilitySlot(weekday: 2, anyTime: true),
        SeekerAvailabilitySlot(weekday: 3, anyTime: true),
        SeekerAvailabilitySlot(weekday: 4, anyTime: true),
        SeekerAvailabilitySlot(weekday: 5, anyTime: true),
        SeekerAvailabilitySlot(weekday: 6, anyTime: true),
      ],
    ),
  ];

  void _applyPreset(_Preset preset) {
    onChanged(availability.withSlots(preset.slots));
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final result = await showModalBottomSheet<List<SeekerAvailabilitySlot>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AddAvailabilitySheet(),
    );
    if (result != null && result.isNotEmpty) {
      onChanged(availability.withSlots(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '자주 쓰는 패턴',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets)
              ActionChip(
                label: Text(preset.label),
                onPressed: () => _applyPreset(preset),
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (availability.slots.isNotEmpty) ...[
          Text(
            '선택한 시간',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in availability.slots)
                InputChip(
                  label: Text(slot.displayLabel),
                  onDeleted: () =>
                      onChanged(availability.withoutSlot(slot)),
                  deleteIconColor: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Text(
          '요일별 상세',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(7, (weekday) {
          final daySlots = availability.slotsForWeekday(weekday);
          return _DayCard(
            weekday: weekday,
            slots: daySlots,
            onRemove: (slot) => onChanged(availability.withoutSlot(slot)),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openAddSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('근무 가능 시간 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _Preset {
  const _Preset({required this.label, required this.slots});
  final String label;
  final List<SeekerAvailabilitySlot> slots;
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.slots,
    required this.onRemove,
  });

  final int weekday;
  final List<SeekerAvailabilitySlot> slots;
  final ValueChanged<SeekerAvailabilitySlot> onRemove;

  @override
  Widget build(BuildContext context) {
    final label = SeekerAvailabilitySlot.weekdayLabels[weekday];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: slots.isEmpty
                ? Text(
                    '시간 미설정',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final slot in slots)
                        Chip(
                          label: Text(
                            slot.anyTime
                                ? '무관'
                                : '${SeekerAvailabilitySlot.formatMinutes(slot.startMinutes!)}–${SeekerAvailabilitySlot.formatMinutes(slot.endMinutes!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () => onRemove(slot),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddAvailabilitySheet extends StatefulWidget {
  const _AddAvailabilitySheet();

  @override
  State<_AddAvailabilitySheet> createState() => _AddAvailabilitySheetState();
}

class _AddAvailabilitySheetState extends State<_AddAvailabilitySheet> {
  final _selectedDays = <int>{0};
  var _anyTime = false;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
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
    });
  }

  void _submit() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요일을 하나 이상 선택해 주세요.')),
      );
      return;
    }
    if (!_anyTime && _toMinutes(_start) >= _toMinutes(_end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 합니다.')),
      );
      return;
    }
    final slots = _selectedDays.map((day) {
      return SeekerAvailabilitySlot(
        weekday: day,
        startMinutes: _anyTime ? null : _toMinutes(_start),
        endMinutes: _anyTime ? null : _toMinutes(_end),
        anyTime: _anyTime,
      );
    }).toList();
    Navigator.of(context).pop(slots);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '근무 가능 시간 추가',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            '요일 선택',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (index) {
              final selected = _selectedDays.contains(index);
              return FilterChip(
                label: Text(SeekerAvailabilitySlot.weekdayLabels[index]),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedDays.add(index);
                    } else {
                      _selectedDays.remove(index);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _anyTime,
              onChanged: (value) => setState(() => _anyTime = value ?? false),
              title: const Text('시간 무관'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          if (!_anyTime) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: Text(
                      '시작 ${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: Text(
                      '종료 ${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}
