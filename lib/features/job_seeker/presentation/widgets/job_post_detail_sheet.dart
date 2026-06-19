import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark_folder.dart';
import 'package:map/core/trust/presentation/employer_trust_section.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:map/features/commute/domain/services/shuttle_reminder_service.dart';
import 'package:map/features/commute/presentation/widgets/nearest_shuttle_stop_card.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_booking_sheet.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_transport_widgets.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/presentation/widgets/easy_salary_calculator_section.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_apply_flow_sheet.dart';

/// 지도 핀 탭 시 공고 상세 바텀시트
class JobPostDetailSheet extends StatefulWidget {
  const JobPostDetailSheet({
    super.key,
    required this.pin,
    required this.onClose,
    required this.onApply,
    this.vaultRepo,
    this.onVaultChanged,
    this.shuttleRoute,
    this.onShowRouteOnMap,
    this.embeddedInPage = false,
    this.onBookmarkStateChanged,
  });

  final JobMapPin pin;
  final VoidCallback onClose;
  final VoidCallback onApply;
  final JobBookmarkVaultRepository? vaultRepo;
  final VoidCallback? onVaultChanged;
  final CommuteRoute? shuttleRoute;
  final VoidCallback? onShowRouteOnMap;
  final bool embeddedInPage;
  final ValueChanged<bool>? onBookmarkStateChanged;

  @override
  State<JobPostDetailSheet> createState() => JobPostDetailSheetState();
}

class JobPostDetailSheetState extends State<JobPostDetailSheet> {
  bool _isBookmarked = false;
  bool _vaultBusy = false;

  bool get isBookmarked => _isBookmarked;
  bool get vaultBusy => _vaultBusy;

  Future<void> applyFromExternal() => _apply();

  Future<void> toggleBookmarkFromExternal() => _toggleBookmark();
  ShuttleBookingSelection? _pendingShuttleSelection;

  @override
  void initState() {
    super.initState();
    _syncVaultState();
  }

  Future<void> _syncVaultState() async {
    final repo = widget.vaultRepo;
    if (repo == null) return;
    await repo.recordViewed(widget.pin);
    final saved = await repo.isBookmarked(widget.pin.post.id);
    if (!mounted) return;
    setState(() => _isBookmarked = saved);
    widget.onBookmarkStateChanged?.call(saved);
    widget.onVaultChanged?.call();
  }

  Future<void> _toggleBookmark() async {
    final repo = widget.vaultRepo;
    if (repo == null || _vaultBusy) return;
    setState(() => _vaultBusy = true);
    try {
      if (_isBookmarked) {
        await repo.removeBookmark(widget.pin.post.id);
        if (!mounted) return;
        setState(() => _isBookmarked = false);
        widget.onBookmarkStateChanged?.call(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보관함에서 삭제했습니다.')),
        );
      } else {
        final folderId = await _pickFolder(repo);
        if (folderId == null) return;
        await repo.saveBookmark(widget.pin, folderId: folderId);
        if (!mounted) return;
        setState(() => _isBookmarked = true);
        widget.onBookmarkStateChanged?.call(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보관함에 저장했습니다.')),
        );
      }
      widget.onVaultChanged?.call();
    } finally {
      if (mounted) setState(() => _vaultBusy = false);
    }
  }

  Future<String?> _pickFolder(JobBookmarkVaultRepository repo) async {
    final folders = await repo.loadFolders();
    if (!mounted) return JobBookmarkFolder.defaultFolderId;
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '저장할 폴더',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ...folders.map(
              (folder) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                onTap: () => Navigator.of(ctx).pop(folder.id),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('새 폴더 만들기'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final created = await _createFolder(repo);
                if (created != null && mounted) {
                  await repo.saveBookmark(widget.pin, folderId: created);
                  setState(() => _isBookmarked = true);
                  widget.onVaultChanged?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('보관함에 저장했습니다.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply() async {
    await showJobApplyDialog(
      context,
      widget.pin,
      onApplied: widget.onApply,
      presetShuttleSelection: _pendingShuttleSelection,
    );
  }

  Future<void> _openShuttleBooking(CommuteRoute route) async {
    final sel = await showShuttleBookingSheet(
      context,
      route: route,
      initialStop: _pendingShuttleSelection?.stop,
    );
    if (sel == null || !mounted) return;
    setState(() => _pendingShuttleSelection = sel);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sel.stop.label} 탑승이 선택되었습니다. 지원 시 함께 저장됩니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _createFolder(JobBookmarkVaultRepository repo) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 만들기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '폴더 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return null;
    try {
      final folder = await repo.createFolder(name);
      return folder.id;
    } on ArgumentError catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '폴더를 만들 수 없습니다.')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final post = pin.post;
    final payDay = post.paymentScheduleDisplayLabel ?? '협의';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: widget.embeddedInPage
            ? null
            : BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x337C5CFC),
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.only(bottom: widget.embeddedInPage ? 0 : 8),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, widget.embeddedInPage ? 16 : 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.embeddedInPage) ...[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pin.companyName,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 8),
                          EmployerTrustSection(
                            companyKey: post.registeredBy?.companyKey,
                            profile: post.registeredBy,
                          ),
                          if (widget.shuttleRoute != null) ...[
                            const SizedBox(height: 10),
                            ShuttleBenefitChips(compact: true),
                          ],
                        ],
                      ),
                    ),
                    _StatusChip(status: post.status),
                  ],
                ),
                if (widget.shuttleRoute != null) ...[
                  const SizedBox(height: 12),
                  ShuttleTransportDetailCard(
                    route: widget.shuttleRoute,
                    loading: false,
                    onShowRouteOnMap: widget.onShowRouteOnMap,
                  ),
                  const SizedBox(height: 12),
                  NearestShuttleStopCard(route: widget.shuttleRoute!),
                  const SizedBox(height: 12),
                  if (_pendingShuttleSelection != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '선택: ${_pendingShuttleSelection!.stop.label} '
                        '${_pendingShuttleSelection!.pickupTime} 탑승',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _openShuttleBooking(widget.shuttleRoute!),
                    icon: const Icon(Icons.directions_bus),
                    label: const Text(
                      '셔틀 이용 신청',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    post.fullDescriptionText,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: '근무지', value: post.warehouseName),
                const SizedBox(height: 8),
                _InfoRow(label: '고용 형태', value: post.employmentType.label),
                const SizedBox(height: 12),
                EasySalaryCalculatorSection(post: post),
                const SizedBox(height: 8),
                _InfoRow(label: '시급', value: post.hourlyWage),
                if (post.dailyWage != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: '일급', value: post.dailyWage!),
                ],
                const SizedBox(height: 8),
                _InfoRow(label: '근무 일정', value: post.workSchedule),
                const SizedBox(height: 8),
                _InfoRow(label: '급여지급일', value: payDay),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showDirectionsStub(context, post.warehouseName),
                    icon: const Icon(Icons.directions_bus_outlined, size: 18),
                    label: const Text('길찾기'),
                  ),
                ),
                if (widget.vaultRepo != null && !widget.embeddedInPage) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _vaultBusy ? null : _toggleBookmark,
                      icon: Icon(
                        _isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                      label: Text(
                        _isBookmarked ? '보관함에 저장됨' : '보관함에 저장',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isBookmarked
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.primaryLight.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                if (!widget.embeddedInPage) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onClose,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color:
                                  AppColors.primaryLight.withValues(alpha: 0.6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '닫기',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _apply,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '지원하기',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showDirectionsStub(BuildContext context, String destination) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('길찾기 기능 준비중: $destination'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CorporateJobPostStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> showJobApplyDialog(
  BuildContext context,
  JobMapPin pin, {
  VoidCallback? onApplied,
  ShuttleBookingSelection? presetShuttleSelection,
}) async {
  final user = AuthSession.instance.currentUser;
  final repo = await JobApplicationRepository.create(user?.email);
  final hiringRepo = await LocalHiringRepository.create();

  if (user != null &&
      !await ensureSeekerAttendanceAccess(context, user.email)) {
    return false;
  }
  if (!context.mounted) return false;

  if (user != null && await hiringRepo.hasApplied(pin.post.id, user.email)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미 「${pin.post.title}」에 지원하셨습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  CommuteRoute? shuttleRoute;
  if (pin.post.commuteRouteId != null) {
    final routeRepo = await CommuteRouteRepository.create();
    final loaded = await routeRepo.findById(pin.post.commuteRouteId!);
    if (loaded != null && ShuttleRouteVisibility.hasSeekerVisibleStops(loaded)) {
      shuttleRoute = ShuttleRouteVisibility.forSeekerDisplay(loaded);
    }
  }

  if (!context.mounted) return false;

  final flowResult = await showJobApplyFlowSheet(
    context,
    postTitle: pin.post.title,
    hasShuttle: shuttleRoute != null,
    shuttleRoute: shuttleRoute,
  );

  if (flowResult == null || !context.mounted || user == null) return false;

  final shuttleSel = flowResult.shuttleSelection ?? presetShuttleSelection;
  String? bookingId;
  if (shuttleSel != null && shuttleRoute != null) {
    final shiftDateIso =
        '${flowResult.shiftDate.year}-${flowResult.shiftDate.month.toString().padLeft(2, '0')}-${flowResult.shiftDate.day.toString().padLeft(2, '0')}';
    bookingId = 'book_${DateTime.now().millisecondsSinceEpoch}';
    final booking = ShuttleBooking(
      id: bookingId,
      seekerEmail: user.email,
      postId: pin.post.id,
      routeId: shuttleRoute.id,
      stopId: shuttleSel.stop.id,
      stopLabel: shuttleSel.stop.label,
      pickupTime: shuttleSel.pickupTime,
      shiftDate: shiftDateIso,
      createdAt: DateTime.now(),
    );
    final bookingRepo = await ShuttleBookingRepository.create();
    await bookingRepo.save(booking);
    final reminderService = await ShuttleReminderService.create();
    await reminderService.scheduleForBooking(booking);
  }

  final phone = user.phone ?? '010-0000-0000';
  final shiftDateIso =
      '${flowResult.shiftDate.year}-${flowResult.shiftDate.month.toString().padLeft(2, '0')}-${flowResult.shiftDate.day.toString().padLeft(2, '0')}';

  await hiringRepo.submitApplication(
    postId: pin.post.id,
    postTitle: pin.post.title,
    companyName: pin.companyName,
    companyKey: pin.post.registeredBy?.companyKey,
    recruiterEmail: pin.post.recruiterEmail,
    branchId: pin.post.branchId,
    branchName: pin.post.branchName,
    workplaceLatitude: pin.latitude != 0 ? pin.latitude : null,
    workplaceLongitude: pin.longitude != 0 ? pin.longitude : null,
    seekerEmail: user.email,
    seekerName: user.name,
    seekerPhoneMasked: phone,
    workSchedule: pin.post.workSchedule,
    suggestedWorkDate: flowResult.shiftDate,
    hourlyWageText: pin.post.hourlyWage,
    employmentType: pin.post.employmentType,
    selectedShiftDate: shiftDateIso,
    shiftSlot: flowResult.shiftSlot,
    shuttleBookingId: bookingId,
    preferredStopId: shuttleSel?.stop.id,
  );

  if (repo != null) {
    await repo.add(
      JobApplication(
        postId: pin.post.id,
        title: pin.post.title,
        company: pin.companyName,
        appliedAt: DateTime.now(),
        status: HiringApplicationStatus.applied.label,
        companyKey: pin.post.registeredBy?.companyKey,
        selectedShiftDate: shiftDateIso,
        shiftSlot: flowResult.shiftSlot,
        shuttleBookingId: bookingId,
        preferredStopId: shuttleSel?.stop.id,
      ),
    );
  }
  if (!context.mounted) return false;
  final shuttleNote = shuttleSel != null ? ' · 셔틀 ${shuttleSel.stop.label}' : '';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('「${pin.post.title}」 지원이 접수되었습니다$shuttleNote'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '내 지원',
          onPressed: onApplied ?? () {},
        ),
      ),
    );
  onApplied?.call();
  return true;
}

String employmentTypeLabel(JobEmploymentType type) => type.label;
