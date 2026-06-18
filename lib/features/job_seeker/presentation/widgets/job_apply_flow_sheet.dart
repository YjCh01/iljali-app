import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_booking_sheet.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';

/// 지원 플로우 결과
class JobApplyFlowResult {
  const JobApplyFlowResult({
    required this.shiftDate,
    required this.shiftSlot,
    this.shuttleSelection,
  });

  final DateTime shiftDate;

  /// day | night | any
  final String shiftSlot;
  final ShuttleBookingSelection? shuttleSelection;
}

Future<JobApplyFlowResult?> showJobApplyFlowSheet(
  BuildContext context, {
  required String postTitle,
  required bool hasShuttle,
  CommuteRoute? shuttleRoute,
}) {
  return showModalBottomSheet<JobApplyFlowResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _JobApplyFlowBody(
      postTitle: postTitle,
      hasShuttle: hasShuttle,
      shuttleRoute: shuttleRoute,
    ),
  );
}

class _JobApplyFlowBody extends StatefulWidget {
  const _JobApplyFlowBody({
    required this.postTitle,
    required this.hasShuttle,
    this.shuttleRoute,
  });

  final String postTitle;
  final bool hasShuttle;
  final CommuteRoute? shuttleRoute;

  @override
  State<_JobApplyFlowBody> createState() => _JobApplyFlowBodyState();
}

class _JobApplyFlowBodyState extends State<_JobApplyFlowBody> {
  int _step = 0;
  late DateTime _selectedDate;
  String _shiftSlot = 'any';
  ShuttleBookingSelection? _shuttleSelection;
  bool _skipShuttle = false;

  static final _dateFormat = DateFormat('M/d');

  List<DateTime> get _dates {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return List.generate(14, (i) => start.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates.first;
  }

  void _next() {
    if (_step == 0) {
      if (widget.hasShuttle && widget.shuttleRoute != null) {
        setState(() => _step = 1);
      } else {
        _finish();
      }
      return;
    }
    _finish();
  }

  void _finish() {
    Navigator.of(context).pop(
      JobApplyFlowResult(
        shiftDate: _selectedDate,
        shiftSlot: _shiftSlot,
        shuttleSelection: _skipShuttle ? null : _shuttleSelection,
      ),
    );
  }

  Future<void> _pickShuttle() async {
    final route = widget.shuttleRoute;
    if (route == null) return;
    final sel = await showShuttleBookingSheet(context, route: route);
    if (sel == null || !mounted) return;
    setState(() {
      _shuttleSelection = sel;
      _skipShuttle = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _step == 0 ? '근무 일정 선택' : '셔틀 이용',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.postTitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            if (_step == 0) ...[
              const Text(
                '희망 근무일',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _dates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = _dates[index];
                    final selected = d.year == _selectedDate.year &&
                        d.month == _selectedDate.month &&
                        d.day == _selectedDate.day;
                    return ChoiceChip(
                      label: Text(
                        _dateFormat.format(d),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedDate = d),
                      selectedColor: AppColors.primaryLight.withValues(alpha: 0.4),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '교대',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _slotChip('day', ShiftSlotKind.day.label),
                  _slotChip('night', ShiftSlotKind.night.label),
                  _slotChip('any', '상관없음'),
                ],
              ),
            ] else ...[
              if (_shuttleSelection != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shuttleSelection!.stop.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade900,
                        ),
                      ),
                      Text(
                        '탑승 ${_shuttleSelection!.pickupTime}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _pickShuttle,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text(
                  '셔틀 탑승장 선택',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _skipShuttle = true;
                    _shuttleSelection = null;
                  });
                  _finish();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  '셔틀 없이 지원',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_step == 0 || (_step == 1 && _shuttleSelection != null))
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _step == 0 ? '다음' : '지원 완료',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotChip(String value, String label) {
    final selected = _shiftSlot == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      selected: selected,
      onSelected: (_) => setState(() => _shiftSlot = value),
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.4),
    );
  }
}
