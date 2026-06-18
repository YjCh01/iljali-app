import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/hiring/attendance_geofence_service.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/attendance_escalation_service.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/seeker_no_show_blacklist_service.dart';
import 'package:map/features/attendance/presentation/widgets/attendance_month_calendar.dart';
import 'package:map/features/corporate/data/datasources/corporate_attendance_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_attendance_usecase.dart';
import 'package:map/features/corporate/presentation/pages/corporate_applicant_resume_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_attendance_card.dart';
import 'package:map/features/corporate/presentation/widgets/employer_attendance_headcount_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/today_attendance_grid.dart';
import 'package:map/features/hiring/presentation/widgets/commission_payment_dialog.dart';

enum _AttendanceViewMode {
  todayRollCall,
  byApplicant,
}

enum _AttendanceSortMode {
  name,
  workConfirmed,
  applied,
}

enum _EmployerWorkerFilter {
  all,
  daily,
  other,
}

extension _EmployerWorkerFilterX on _EmployerWorkerFilter {
  String get label => switch (this) {
        _EmployerWorkerFilter.all => '전체',
        _EmployerWorkerFilter.daily => '일용직',
        _EmployerWorkerFilter.other => '그 외',
      };
}

extension _AttendanceSortModeX on _AttendanceSortMode {
  String get label => switch (this) {
        _AttendanceSortMode.name => '가나다순',
        _AttendanceSortMode.workConfirmed => '근무확정순',
        _AttendanceSortMode.applied => '지원순',
      };
}

/// 기업회원 4번 탭 — 근태 관리 · 수수료 결제
class CorporateAttendanceTab extends StatefulWidget {
  const CorporateAttendanceTab({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<CorporateAttendanceTab> createState() => _CorporateAttendanceTabState();
}

class _CorporateAttendanceTabState extends State<CorporateAttendanceTab> {
  final _getAttendance = const GetCorporateAttendanceUseCase(
    CorporateAttendanceLocalDataSourceImpl(),
  );

  List<CorporateAttendanceRecord> _records = [];
  bool _loading = true;
  _AttendanceViewMode _viewMode = _AttendanceViewMode.todayRollCall;
  _AttendanceSortMode _sortMode = _AttendanceSortMode.workConfirmed;
  DateTime _selectedDay = DateTime.now();
  _EmployerWorkerFilter _workerFilter = _EmployerWorkerFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant CorporateAttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load();
      return;
    }
    if (widget.isActive && HiringRefresh.consumeIfDirty()) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (ProductFeatureFlags.isHiringCommissionEnabled) {
      await AttendanceEscalationService.runEscalationPass(context);
    }
    final records = await _getAttendance();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
    await _promptPendingCommissions();
  }

  List<CorporateAttendanceRecord> get _filteredRecords {
    return _records.where((record) {
      return switch (_workerFilter) {
        _EmployerWorkerFilter.all => true,
        _EmployerWorkerFilter.daily => record.isDailyWorker,
        _EmployerWorkerFilter.other => !record.isDailyWorker,
      };
    }).toList();
  }

  List<CorporateAttendanceRecord> get _todayRecords {
    final today = _filteredRecords.where((r) => r.isWorkScheduledToday).toList();
    today.sort((a, b) => a.workerName.compareTo(b.workerName));
    return today;
  }

  List<CorporateAttendanceRecord> get _selectedDayRecords {
    final selected = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final list = _filteredRecords.where((record) {
      final date = record.workDate;
      if (date == null) return false;
      final normalized = DateTime(date.year, date.month, date.day);
      return normalized == selected;
    }).toList();
    list.sort((a, b) => a.workerName.compareTo(b.workerName));
    return list;
  }

  List<AttendanceCalendarDayEntry> get _calendarEntries {
    final grouped = <DateTime, List<CorporateAttendanceRecord>>{};
    for (final record in _filteredRecords) {
      final date = record.workDate;
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(key, () => []).add(record);
    }

    return grouped.entries.map((entry) {
      final records = entry.value;
      AttendanceDayMarker marker = AttendanceDayMarker.none;
      for (final record in records) {
        final next = switch (record.rollCallStatus) {
          TodayRollCallStatus.absent => AttendanceDayMarker.absent,
          TodayRollCallStatus.present => AttendanceDayMarker.checkedIn,
          TodayRollCallStatus.pending => record.canEmployerConfirm ||
                  record.awaitingSeekerCheckIn
              ? AttendanceDayMarker.pending
              : AttendanceDayMarker.scheduled,
        };
        marker = _preferMarker(marker, next);
      }
      return AttendanceCalendarDayEntry(
        date: entry.key,
        marker: marker,
        count: records.length,
      );
    }).toList();
  }

  AttendanceDayMarker _preferMarker(
    AttendanceDayMarker current,
    AttendanceDayMarker next,
  ) {
    const priority = [
      AttendanceDayMarker.none,
      AttendanceDayMarker.scheduled,
      AttendanceDayMarker.pending,
      AttendanceDayMarker.checkedIn,
      AttendanceDayMarker.absent,
    ];
    return priority.indexOf(next) > priority.indexOf(current) ? next : current;
  }

  int get _onDutyCount => _todayRecords
      .where(
        (r) =>
            r.rollCallStatus == TodayRollCallStatus.present ||
            r.rollCallStatus == TodayRollCallStatus.pending,
      )
      .length;

  int get _onDutyDailyCount => _todayRecords
      .where(
        (r) =>
            r.isDailyWorker &&
            (r.rollCallStatus == TodayRollCallStatus.present ||
                r.rollCallStatus == TodayRollCallStatus.pending),
      )
      .length;

  int get _onDutyOtherCount => _onDutyCount - _onDutyDailyCount;

  List<CorporateAttendanceRecord> get _sortedApplicantRecords {
    final list = List<CorporateAttendanceRecord>.from(_filteredRecords);
    switch (_sortMode) {
      case _AttendanceSortMode.name:
        list.sort((a, b) => a.workerName.compareTo(b.workerName));
      case _AttendanceSortMode.workConfirmed:
        list.sort((a, b) {
          final aDate = a.workAgreedAt ?? a.appliedAt;
          final bDate = b.workAgreedAt ?? b.appliedAt;
          return bDate.compareTo(aDate);
        });
      case _AttendanceSortMode.applied:
        list.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    }
    return list;
  }

  Future<void> _promptPendingCommissions() async {
    if (!ProductFeatureFlags.isHiringCommissionEnabled) return;
    final repo = await LocalHiringRepository.create();
    final pending = await repo.fetchPendingCommissions();
    if (!mounted) return;
    for (final app in pending) {
      final paid = await showCommissionPaymentDialog(context, app);
      if (paid == true) break;
    }
    if (pending.isNotEmpty && mounted) await _load();
  }

  Future<void> _openApplicantProfile(CorporateAttendanceRecord record) async {
    final id = record.applicationId;
    if (id == null || id.isEmpty || !mounted) return;
    await openCorporateApplicantResume(context, applicationId: id);
  }

  Future<void> _openRecord(CorporateAttendanceRecord record) async {
    if (record.applicationId == null) return;
    final repo = await LocalHiringRepository.create();
    final app = await repo.findById(record.applicationId!);
    if (app == null || !mounted) return;

    if (ProductFeatureFlags.isHiringCommissionEnabled &&
        record.needsCommissionPayment) {
      final paid = await showCommissionPaymentDialog(context, app);
      if (paid == true) await _load();
      return;
    }

    if (record.canEmployerConfirm) {
      await _confirmEmployer(record);
    }
  }

  Future<void> _confirmEmployer(CorporateAttendanceRecord record) async {
    if (!record.canEmployerConfirm) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('출근 확인'),
        content: Text(
          ProductFeatureFlags.isHiringCommissionEnabled
              ? '${record.workerName}님의 출근을 확인하시겠습니까?\n'
                  '구직자와 기업 모두 확인해야 성공 수수료가 발생합니다.'
              : '${record.workerName}님의 출근을 확인하시겠습니까?\n'
                  '구직자와 기업 모두 확인하면 출근 기록이 완료됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('출근 확인'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = await LocalHiringRepository.create();
      final app = await repo.findById(record.applicationId!);
      if (app == null || !mounted) return;

      final geofence = await AttendanceGeofenceService.evaluateCurrent(
        workplace: app.workplaceCoordinate,
      );
      final detailed = await DeviceLocationService.getCurrentPositionDetailed();

      await AttendanceGeofenceService.logVerificationAttempt(
        applicationId: app.id,
        role: 'employer',
        result: geofence,
        latitude: detailed?.coordinate.latitude,
        longitude: detailed?.coordinate.longitude,
        companyKey: app.companyKey,
      );

      if (!geofence.allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(geofence.userMessage)),
        );
        return;
      }

      final updated = await repo.confirmEmployerAttendance(
        record.applicationId!,
        latitude: detailed?.coordinate.latitude,
        longitude: detailed?.coordinate.longitude,
        geofenceVerified: geofence.allowed,
        geofenceDistanceMeters: geofence.distanceMeters,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isMutuallyConfirmed
                ? (ProductFeatureFlags.isHiringCommissionEnabled
                    ? '상호 출근 확인이 완료되었습니다. 수수료 결제를 진행해 주세요.'
                    : '상호 출근 확인이 완료되었습니다.')
                : '기업 출근 확인 완료. 구직자 출근 체크를 기다리는 중입니다.',
          ),
        ),
      );
      await _load();
    } on StateError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'not_scheduled' => '출근 예정 상태에서만 확인할 수 있습니다.',
        'geofence_failed' => '근무지 반경 내에서만 출근 확정할 수 있습니다.',
        _ => '출근 확인에 실패했습니다.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _markNoShow(CorporateAttendanceRecord record) async {
    if (record.applicationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노쇼 처리'),
        content: Text(
          '${record.workerName}님을 노쇼로 처리하시겠습니까?\n'
          '구인자 확인 즉시 확정되며, 3연속 노쇼 시 서비스 이용이 제한될 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('노쇼 확정'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = await LocalHiringRepository.create();
      final updated = await repo.markNoShowByEmployer(record.applicationId!);
      final blacklist = await SeekerNoShowBlacklistService.create();
      final result = await blacklist.recordEmployerNoShow(
        seekerEmail: updated.seekerEmail,
        hiringRepo: repo,
      );
      if (!mounted) return;
      final suffix = result.blacklisted
          ? ' (연속 ${result.consecutiveCount}회 — 블랙리스트 등록)'
          : ' (연속 ${result.consecutiveCount}회)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('노쇼로 처리되었습니다.$suffix')),
      );
      await _load();
    } on StateError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'agreement_incomplete' => '근무예정 합의가 완료된 건만 노쇼 처리할 수 있습니다.',
        'not_scheduled' => '출근 예정 상태에서만 노쇼 처리할 수 있습니다.',
        'already_completed' => '이미 근무 확인이 완료된 건입니다.',
        _ => '노쇼 처리에 실패했습니다.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (_onDutyCount > 0) ...[
              EmployerAttendanceHeadcountBanner(
                count: _onDutyCount,
                dailyCount: _onDutyDailyCount,
                otherCount: _onDutyOtherCount,
                onTap: () => showEmployerAttendanceHeadcountSheet(
                  context,
                  todayRecords: _todayRecords,
                ),
              ),
              const SizedBox(height: 14),
            ],
            AttendanceMonthCalendar(
              entries: _calendarEntries,
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
              headerTrailing: _WorkerFilterMenu(
                filter: _workerFilter,
                onChanged: (filter) => setState(() => _workerFilter = filter),
              ),
            ),
            const SizedBox(height: 14),
            _SelectedDayHeader(
              day: _selectedDay,
              count: _selectedDayRecords.length,
            ),
            const SizedBox(height: 10),
            if (_selectedDayRecords.isNotEmpty)
              ..._selectedDayRecords.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CorporateAttendanceCard(
                    record: record,
                    onTap: record.needsCommissionPayment ||
                            record.canEmployerConfirm
                        ? () => _openRecord(record)
                        : () => _openApplicantProfile(record),
                    onEmployerConfirm: record.canEmployerConfirm
                        ? () => _openRecord(record)
                        : null,
                    onMarkNoShow: record.canMarkNoShow
                        ? () => _markNoShow(record)
                        : null,
                  ),
                ),
              )
            else
              _emptySelectedDay(),
            const SizedBox(height: 18),
            _AttendanceModeSwitcher(
              mode: _viewMode,
              todayCount: _todayRecords.length,
              onChanged: (mode) => setState(() => _viewMode = mode),
            ),
            const SizedBox(height: 14),
            if (_viewMode == _AttendanceViewMode.todayRollCall)
              TodayAttendanceGrid(
                records: _todayRecords,
                onTapRecord: _openApplicantProfile,
              )
            else ...[
              if (_records.isEmpty)
                _emptyByApplicant()
              else ...[
                _SortBar(
                  sortMode: _sortMode,
                  onChanged: (mode) => setState(() => _sortMode = mode),
                ),
                const SizedBox(height: 12),
                ..._sortedApplicantRecords.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CorporateAttendanceCard(
                      record: record,
                      onTap: record.needsCommissionPayment ||
                              record.canEmployerConfirm
                          ? () => _openRecord(record)
                          : () => _openApplicantProfile(record),
                      onEmployerConfirm: record.canEmployerConfirm
                          ? () => _openRecord(record)
                          : null,
                      onMarkNoShow: record.canMarkNoShow
                          ? () => _markNoShow(record)
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptySelectedDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        '선택한 날짜에 근무 예정자가 없습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _emptyByApplicant() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            '근무예정 합의된 건이 없습니다',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '채팅에서 근무예정 합의가 완료되면\n여기에 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceModeSwitcher extends StatelessWidget {
  const _AttendanceModeSwitcher({
    required this.mode,
    required this.todayCount,
    required this.onChanged,
  });

  final _AttendanceViewMode mode;
  final int todayCount;
  final ValueChanged<_AttendanceViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_AttendanceViewMode>(
      segments: [
        ButtonSegment(
          value: _AttendanceViewMode.todayRollCall,
          label: Text('오늘 출근자 명단${todayCount > 0 ? ' ($todayCount)' : ''}'),
        ),
        const ButtonSegment(
          value: _AttendanceViewMode.byApplicant,
          label: Text('지원자별 근태 확인'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label =
        '${day.month}월 ${day.day}일 · $count명';
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _WorkerFilterMenu extends StatelessWidget {
  const _WorkerFilterMenu({
    required this.filter,
    required this.onChanged,
  });

  final _EmployerWorkerFilter filter;
  final ValueChanged<_EmployerWorkerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_EmployerWorkerFilter>(
      tooltip: '근로자 유형 필터',
      initialValue: filter,
      onSelected: onChanged,
      icon: Icon(
        Icons.filter_list_rounded,
        color: filter == _EmployerWorkerFilter.all
            ? AppColors.textSecondary
            : AppColors.primary,
      ),
      itemBuilder: (context) => _EmployerWorkerFilter.values
          .map(
            (value) => PopupMenuItem(
              value: value,
              child: Text(value.label),
            ),
          )
          .toList(),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sortMode,
    required this.onChanged,
  });

  final _AttendanceSortMode sortMode;
  final ValueChanged<_AttendanceSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '정렬',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _AttendanceSortMode.values.map((mode) {
                final selected = mode == sortMode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(mode.label),
                    selected: selected,
                    onSelected: (_) => onChanged(mode),
                    selectedColor: AppColors.primaryLight.withValues(alpha: 0.35),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
