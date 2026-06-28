import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';

/// 30분 단위 스크롤 휠 시간 선택 (오전/오후 · 시 · 분).
Future<TimeOfDay?> showScrollTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  final snapped = snapTimeToHalfHour(initialTime);
  return showAdaptiveSheet<TimeOfDay>(
    context: context,
    builder: (context) => _ScrollTimePickerSheet(initialTime: snapped),
  );
}

/// 분을 00 또는 30으로 맞춥니다. 45분 이후는 다음 시각 00분으로 올립니다.
TimeOfDay snapTimeToHalfHour(TimeOfDay time) {
  final minute = time.minute;
  if (minute <= 15) {
    return TimeOfDay(hour: time.hour, minute: 0);
  }
  if (minute <= 45) {
    return TimeOfDay(hour: time.hour, minute: 30);
  }
  final nextHour = (time.hour + 1) % 24;
  return TimeOfDay(hour: nextHour, minute: 0);
}

class _ScrollTimePickerSheet extends StatefulWidget {
  const _ScrollTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_ScrollTimePickerSheet> createState() => _ScrollTimePickerSheetState();
}

class _ScrollTimePickerSheetState extends State<_ScrollTimePickerSheet> {
  static const _hours = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  static const _minutes = [0, 30];

  late bool _isPm;
  late int _hour12;
  late int _minute;

  late FixedExtentScrollController _meridiemController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final parts = _fromTimeOfDay(widget.initialTime);
    _isPm = parts.isPm;
    _hour12 = parts.hour12;
    _minute = parts.minute;

    _meridiemController = FixedExtentScrollController(initialItem: _isPm ? 1 : 0);
    _hourController = FixedExtentScrollController(
      initialItem: _hours.indexOf(_hour12).clamp(0, _hours.length - 1),
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _minutes.indexOf(_minute).clamp(0, _minutes.length - 1),
    );
  }

  @override
  void dispose() {
    _meridiemController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay get _selectedTime => _toTimeOfDay(
        isPm: _isPm,
        hour12: _hour12,
        minute: _minute,
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: _WheelColumn(
                    label: '오전/오후',
                    controller: _meridiemController,
                    items: const ['오전', '오후'],
                    onSelected: (index) => setState(() => _isPm = index == 1),
                  ),
                ),
                Expanded(
                  child: _WheelColumn(
                    label: '시',
                    controller: _hourController,
                    items: _hours.map((h) => h.toString().padLeft(2, '0')).toList(),
                    onSelected: (index) => setState(() => _hour12 = _hours[index]),
                  ),
                ),
                Expanded(
                  child: _WheelColumn(
                    label: '분',
                    controller: _minuteController,
                    items: _minutes.map((m) => m.toString().padLeft(2, '0')).toList(),
                    onSelected: (index) => setState(() => _minute = _minutes[index]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selectedTime),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.label,
    required this.controller,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final FixedExtentScrollController controller;
  final List<String> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 40,
            magnification: 1.08,
            squeeze: 1.05,
            useMagnifier: true,
            onSelectedItemChanged: onSelected,
            children: items
                .map(
                  (item) => Center(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

({bool isPm, int hour12, int minute}) _fromTimeOfDay(TimeOfDay time) {
  final isPm = time.hour >= 12;
  var hour12 = time.hour % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = time.minute == 30 ? 30 : 0;
  return (isPm: isPm, hour12: hour12, minute: minute);
}

TimeOfDay _toTimeOfDay({
  required bool isPm,
  required int hour12,
  required int minute,
}) {
  var hour24 = hour12 % 12;
  if (isPm) hour24 += 12;
  return TimeOfDay(hour: hour24, minute: minute);
}
