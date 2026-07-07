import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_booking_sheet.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_calendar_utils.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';
import 'package:map/features/corporate/presentation/widgets/work_schedule_calendar_view.dart';

/// 지원 플로우 결과
class JobApplyFlowResult {
  const JobApplyFlowResult({
    required this.selectedDates,
    this.shuttleSelection,
    this.scheduleNegotiable = false,
  });

  /// 선택한 근무일 (정렬됨). 협의 공고는 비어 있을 수 있음.
  final List<DateTime> selectedDates;

  final ShuttleBookingSelection? shuttleSelection;

  /// 근무일정 협의 — 채팅으로 일정 조율
  final bool scheduleNegotiable;

  DateTime? get primaryDate =>
      scheduleNegotiable || selectedDates.isEmpty ? null : selectedDates.first;

  /// 하위 호환 — 교대 선택 UI 제거, 항상 any
  String get shiftSlot => 'any';

  DateTime get shiftDate => primaryDate ?? DateTime.now();
}

Future<JobApplyFlowResult?> showJobApplyFlowSheet(
  BuildContext context, {
  required String postTitle,
  required String workSchedule,
  required WorkerCategory workerCategory,
  required bool hasShuttle,
  required bool workScheduleNegotiable,
  CommuteRoute? shuttleRoute,
}) {
  return showAdaptiveSheet<JobApplyFlowResult>(
    context: context,
    builder: (ctx) => _JobApplyFlowBody(
      postTitle: postTitle,
      workSchedule: workSchedule,
      workerCategory: workerCategory,
      hasShuttle: hasShuttle,
      workScheduleNegotiable: workScheduleNegotiable,
      shuttleRoute: shuttleRoute,
    ),
  );
}

class _JobApplyFlowBody extends StatefulWidget {
  const _JobApplyFlowBody({
    required this.postTitle,
    required this.workSchedule,
    required this.workerCategory,
    required this.hasShuttle,
    required this.workScheduleNegotiable,
    this.shuttleRoute,
  });

  final String postTitle;
  final String workSchedule;
  final WorkerCategory workerCategory;
  final bool hasShuttle;
  final bool workScheduleNegotiable;
  final CommuteRoute? shuttleRoute;

  @override
  State<_JobApplyFlowBody> createState() => _JobApplyFlowBodyState();
}

class _JobApplyFlowBodyState extends State<_JobApplyFlowBody> {
  int _step = 0;
  late WorkScheduleSpec _spec;
  late bool _multiSelect;
  final Set<DateTime> _selectedDates = {};
  ShuttleBookingSelection? _shuttleSelection;
  bool _skipShuttle = false;

  bool get _hasSchedule =>
      WorkScheduleCodec.tryParse(widget.workSchedule) != null;

  @override
  void initState() {
    super.initState();
    _multiSelect = widget.workerCategory == WorkerCategory.daily ||
        widget.workerCategory == WorkerCategory.shortTerm;
    _spec = WorkScheduleCodec.tryParse(widget.workSchedule) ??
        WorkScheduleSpec(mode: WorkScheduleMode.dailyPick);
  }

  (DateTime?, DateTime?) get _periodBounds => _spec.periodBounds();

  List<DateTime> get _months => _spec.monthsToShow();

  List<DateTime> get _allSelectableDays => _spec.seekerSelectableWorkDays();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelected(DateTime date) =>
      _selectedDates.any((d) => _isSameDay(d, date));

  void _toggleDate(DateTime date) {
    final normalized = WorkScheduleCalendarX.dateOnly(date);
    if (!_spec.isSeekerSelectableDay(normalized)) return;

    setState(() {
      if (_multiSelect) {
        if (_isSelected(normalized)) {
          _selectedDates.removeWhere((d) => _isSameDay(d, normalized));
        } else {
          _selectedDates.add(normalized);
        }
      } else {
        _selectedDates
          ..clear()
          ..add(normalized);
      }
    });
  }

  void _selectAllDates() {
    setState(() {
      _selectedDates
        ..clear()
        ..addAll(_allSelectableDays);
    });
  }

  bool get _scheduleNegotiable =>
      widget.workScheduleNegotiable ||
      WorkScheduleNegotiable.isLabel(widget.workSchedule);

  bool get _canProceed =>
      _scheduleNegotiable || _selectedDates.isNotEmpty;

  void _next() {
    if (_step == 0) {
      if (!_canProceed) return;
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
    if (_scheduleNegotiable) {
      Navigator.of(context).pop(
        JobApplyFlowResult(
          selectedDates: const [],
          scheduleNegotiable: true,
          shuttleSelection: _skipShuttle ? null : _shuttleSelection,
        ),
      );
      return;
    }
    final sorted = _selectedDates.toList()..sort();
    Navigator.of(context).pop(
      JobApplyFlowResult(
        selectedDates: sorted,
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

  String get _dateSectionTitle {
    if (_multiSelect) return '근무일자 선택(중복가능)';
    return '근무 시작 희망일';
  }

  @override
  Widget build(BuildContext context) {
    final (periodStart, periodEnd) = _periodBounds;
    final maxCalendarHeight =
        (MediaQuery.of(context).size.height * 0.42).clamp(280.0, 440.0);

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateSectionTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_multiSelect && _allSelectableDays.isNotEmpty)
                    TextButton(
                      onPressed: _selectAllDates,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        '모든날짜 선택하기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (_multiSelect && _selectedDates.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '선택 ${_selectedDates.length}일',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (_scheduleNegotiable)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '이 공고는 근무 일정이 협의 가능합니다.\n'
                    '지원 후 채팅으로 희망 일정을 말씀해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                )
              else if (!_hasSchedule || _allSelectableDays.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _hasSchedule
                        ? '선택 가능한 근무일이 없습니다.\n기업에 문의해 주세요.'
                        : '등록된 근무 일정이 없습니다.\n기업에 문의해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: maxCalendarHeight,
                  child: WorkScheduleCalendarView(
                    spec: _spec,
                    months: _months,
                    periodStart: periodStart,
                    periodEnd: periodEnd,
                    seekerSelectedDates: _selectedDates,
                    singleSelect: !_multiSelect,
                    isDaySelectable: _spec.isSeekerSelectableDay,
                    onDayTap: _toggleDate,
                  ),
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
                onPressed: _canProceed ? _next : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _step == 0 ? '다음' : '지원 완료',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
