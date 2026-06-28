import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';

/// 근무 가능 스케줄 — 요일 다중 선택 + 24h 시계(30분 단위) + 야간(익일) 표시
class SeekerWorkAvailabilityPicker extends StatefulWidget {
  const SeekerWorkAvailabilityPicker({
    super.key,
    required this.availability,
    required this.onChanged,
  });

  final SeekerWorkAvailability availability;
  final ValueChanged<SeekerWorkAvailability> onChanged;

  @override
  State<SeekerWorkAvailabilityPicker> createState() =>
      _SeekerWorkAvailabilityPickerState();
}

class _SeekerWorkAvailabilityPickerState
    extends State<SeekerWorkAvailabilityPicker> {
  final _selectedDays = <int>{0};
  var _anyTime = false;
  late String _startTime;
  late String _endTime;

  static final _timeOptions = SeekerAvailabilitySlot.halfHourTimeOptions;

  @override
  void initState() {
    super.initState();
    _startTime = '09:00';
    _endTime = '18:00';
  }

  bool get _isOvernight {
    if (_anyTime) return false;
    final start = SeekerAvailabilitySlot.parseTimeOption(_startTime)!;
    final end = SeekerAvailabilitySlot.parseTimeOption(_endTime)!;
    return end <= start;
  }

  String get _previewLabel {
    if (_selectedDays.isEmpty) return '요일을 선택해 주세요.';
    if (_anyTime) {
      final days = _selectedDays.map((d) => SeekerAvailabilitySlot.weekdayLabels[d]).join(', ');
      return '$days · 시간 무관';
    }
    final start = SeekerAvailabilitySlot.parseTimeOption(_startTime)!;
    final end = SeekerAvailabilitySlot.parseTimeOption(_endTime)!;
    final overnight = end <= start;
    final dayLabels = _selectedDays.map((day) {
      final endLabel = overnight
          ? '${SeekerAvailabilitySlot.formatMinutes(end)} (${SeekerAvailabilitySlot.weekdayLabels[(day + 1) % 7]})'
          : SeekerAvailabilitySlot.formatMinutes(end);
      return '${SeekerAvailabilitySlot.weekdayLabels[day]} ${SeekerAvailabilitySlot.formatMinutes(start)}–$endLabel';
    });
    return dayLabels.join(' · ');
  }

  void _addSlots() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요일을 하나 이상 선택해 주세요.')),
      );
      return;
    }
    if (!_anyTime) {
      final start = SeekerAvailabilitySlot.parseTimeOption(_startTime);
      final end = SeekerAvailabilitySlot.parseTimeOption(_endTime);
      if (start == null || end == null) return;
      if (start == end) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시작·종료 시간이 같습니다. 시간을 조정해 주세요.')),
        );
        return;
      }
    }

    final slots = _selectedDays.map((day) {
      if (_anyTime) {
        return SeekerAvailabilitySlot(weekday: day, anyTime: true);
      }
      final start = SeekerAvailabilitySlot.parseTimeOption(_startTime)!;
      final end = SeekerAvailabilitySlot.parseTimeOption(_endTime)!;
      final overnight = end <= start;
      return SeekerAvailabilitySlot(
        weekday: day,
        startMinutes: start,
        endMinutes: end,
        endDayOffset: overnight ? 1 : 0,
      );
    }).toList();

    widget.onChanged(widget.availability.withSlots(slots));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '요일 선택 (중복 가능)',
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
            title: const Text('선택한 요일 · 시간 무관'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        if (!_anyTime) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeDropdown(
                  label: '시작',
                  value: _startTime,
                  options: _timeOptions,
                  onChanged: (v) => setState(() => _startTime = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeDropdown(
                  label: '종료',
                  value: _endTime,
                  options: _timeOptions,
                  onChanged: (v) => setState(() => _endTime = v),
                ),
              ),
            ],
          ),
          if (_isOvernight) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.nightlight_round, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '야간 근무 — 종료 시각은 다음날로 표시됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _previewLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _addSlots,
          icon: const Icon(Icons.add_rounded),
          label: const Text('선택한 요일에 시간 추가'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (widget.availability.slots.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '등록된 근무 가능 시간',
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
              for (final slot in widget.availability.slots)
                InputChip(
                  label: Text(slot.displayLabel),
                  onDeleted: () =>
                      widget.onChanged(widget.availability.withoutSlot(slot)),
                  deleteIconColor: AppColors.textSecondary,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.searchBarBorder),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (picked) {
            if (picked != null) onChanged(picked);
          },
        ),
      ),
    );
  }
}
