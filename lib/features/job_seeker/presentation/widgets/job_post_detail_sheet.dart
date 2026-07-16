import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/job_seeker/domain/services/job_post_directions_launcher.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/selected_shift_dates.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark_folder.dart';
import 'package:map/core/trust/presentation/employer_trust_section.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/presentation/widgets/nearest_shuttle_stop_card.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_transport_widgets.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_readiness.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_profile_onboarding_args.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_description_body_view.dart';
import 'package:map/features/job_seeker/presentation/widgets/easy_salary_calculator_section.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_apply_flow_sheet.dart';
import 'package:map/features/job_seeker/presentation/widgets/credential_apply_dialog.dart';
import 'package:map/features/job_seeker/presentation/widgets/resume_disclosure_dialog.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/services/seeker_application_withdraw_service.dart';
import 'package:map/features/job_seeker/domain/policies/seeker_job_actions_policy.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_login_prompt_sheet.dart';

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
    this.onApplicationStateChanged,
    this.employerPreview = false,
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
  final VoidCallback? onApplicationStateChanged;
  final bool employerPreview;

  @override
  State<JobPostDetailSheet> createState() => JobPostDetailSheetState();
}

class JobPostDetailSheetState extends State<JobPostDetailSheet> {
  bool _isBookmarked = false;
  bool _vaultBusy = false;
  bool _hasApplied = false;
  bool _canWithdraw = false;
  bool _withdrawBusy = false;

  bool get isBookmarked => _isBookmarked;
  bool get vaultBusy => _vaultBusy;
  bool get hasApplied => _hasApplied;
  bool get canWithdrawApplication => _canWithdraw;

  bool get _showSeekerActions =>
      SeekerJobActionsPolicy.showSeekerActionUi(
        employerPreview: widget.employerPreview,
      );

  Future<void> applyFromExternal() => _apply();
  Future<void> withdrawFromExternal() => _withdrawApplication();
  Future<void> refreshApplicationState() => _loadApplicationState();

  Future<void> toggleBookmarkFromExternal() => _toggleBookmark();

  @override
  void initState() {
    super.initState();
    _syncVaultState();
    _loadApplicationState();
    if (IljariApiClient().isEnabled) {
      IljariApiClient().recordJobPostView(widget.pin.post.id);
    }
  }

  Future<void> _loadApplicationState() async {
    if (!SeekerShellAccess.isSignedInSeeker) {
      if (!mounted) return;
      setState(() {
        _hasApplied = false;
        _canWithdraw = false;
      });
      return;
    }
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;
    final repo = await LocalHiringRepository.create();
    final active = await repo.findActiveForPost(
      postId: widget.pin.post.id,
      seekerEmail: email,
    );
    if (!mounted) return;
    setState(() {
      _hasApplied = active != null && active.status.countsAsApplied;
      _canWithdraw = active != null &&
          LocalHiringRepository.canSeekerWithdraw(active);
    });
    widget.onApplicationStateChanged?.call();
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
    if (!SeekerShellAccess.isSignedInSeeker) {
      await SeekerLoginPromptSheet.show(
        context,
        message: '보관함에 저장하려면 개인회원 로그인이 필요합니다.',
      );
      return;
    }

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
    return showAdaptiveSheet<String>(
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
    if (!_showSeekerActions) return;
    await showJobApplyDialog(
      context,
      widget.pin,
      onApplied: () async {
        widget.onApply();
        await _loadApplicationState();
      },
    );
    await _loadApplicationState();
  }

  Future<void> _withdrawApplication() async {
    if (_withdrawBusy || !_canWithdraw) return;
    setState(() => _withdrawBusy = true);
    try {
      final ok = await SeekerApplicationWithdrawService.confirmAndWithdraw(
        context,
        postId: widget.pin.post.id,
        postTitle: widget.pin.post.title,
      );
      if (ok) await _loadApplicationState();
    } finally {
      if (mounted) setState(() => _withdrawBusy = false);
    }
  }

  Future<void> _openDirections() async {
    await JobPostDirectionsLauncher.openWalkingFromHome(
      context,
      widget.pin,
      employerPreview: widget.employerPreview,
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '채용이 확정되면 「내 버스」에서 탑승 노선과 정류장을 선택할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
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
                  child: JobPostDescriptionBodyView(
                    body: post.effectiveDescriptionBody,
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: '근무지', value: post.warehouseName),
                const SizedBox(height: 8),
                _InfoRow(
                  label: '고용 형태',
                  value: post.effectiveWorkerCategory.label,
                ),
                const SizedBox(height: 12),
                EasySalaryCalculatorSection(post: post),
                const SizedBox(height: 8),
                _InfoRow(label: '시급', value: post.hourlyWage),
                if (post.dailyWage != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: '일급', value: post.dailyWage!),
                ],
                const SizedBox(height: 8),
                _InfoRow(
                  label: '근무 일정',
                  value: post.workScheduleDisplayLabel,
                ),
                const SizedBox(height: 8),
                _InfoRow(label: '급여지급일', value: payDay),
                if (post.requiredCredentialIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: '필수 자격',
                    value: CredentialCatalog.labelsForIds(
                      post.requiredCredentialIds,
                    ).join(', '),
                  ),
                ],
                if (post.requiredResumeItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: '이력서 확인',
                    value: post.requiredResumeItems
                        .map((k) => k.label)
                        .join(', '),
                  ),
                ],
                const SizedBox(height: 6),
                if (_showSeekerActions)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openDirections,
                      icon: const Icon(Icons.directions_walk, size: 18),
                      label: const Text('길찾기'),
                    ),
                  ),
                if (widget.vaultRepo != null &&
                    !widget.embeddedInPage &&
                    _showSeekerActions) ...[
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
                      if (_showSeekerActions && _canWithdraw) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _withdrawBusy ? null : _withdrawApplication,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(
                                color: Colors.red.shade300,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '지원취소',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                      if (_showSeekerActions) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _hasApplied ? null : _apply,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primaryLight.withValues(alpha: 0.35),
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _hasApplied ? '지원 완료' : '지원하기',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
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

Future<bool> _ensureMatchingProfileForApply(BuildContext context) async {
  final user = AuthSession.instance.currentUser;
  if (user == null) return false;

  if (SeekerProfileReadiness.isMatchingReady(
    user.seekerProfile,
    displayName: user.name,
  )) {
    return true;
  }

  final completed = await Navigator.of(context).pushNamed<bool>(
    AppRoutes.seekerProfileOnboarding,
    arguments: SeekerProfileOnboardingArgs.forApply,
  );
  if (completed != true || !context.mounted) return false;

  final refreshed = AuthSession.instance.currentUser;
  if (SeekerProfileReadiness.isMatchingReady(
    refreshed?.seekerProfile,
    displayName: refreshed?.name,
  )) {
    return true;
  }

  final missing = SeekerProfileReadiness.missingMatchingFields(
    refreshed?.seekerProfile,
    displayName: refreshed?.name,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          missing.isEmpty
              ? SeekerProfileReadiness.applyBlockedMessage
              : '아직 입력이 필요합니다: ${missing.join(', ')}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return false;
}

Future<bool> showJobApplyDialog(
  BuildContext context,
  JobMapPin pin, {
  VoidCallback? onApplied,
}) async {
  if (!await SeekerJobActionsPolicy.ensureCanApply(context)) {
    return false;
  }

  if (!await _ensureMatchingProfileForApply(context)) {
    return false;
  }
  if (!context.mounted) return false;

  final user = AuthSession.instance.currentUser;
  if (user == null) return false;

  final repo = await JobApplicationRepository.create(user.email);
  final hiringRepo = await LocalHiringRepository.create();

  if (!await ensureSeekerAttendanceAccess(context, user.email)) {
    return false;
  }
  if (!context.mounted) return false;

  if (await hiringRepo.hasApplied(pin.post.id, user.email)) {
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

  if (!context.mounted) return false;

  final flowResult = await showJobApplyFlowSheet(
    context,
    postTitle: pin.post.title,
    workSchedule: pin.post.workSchedule,
    workerCategory: pin.post.effectiveWorkerCategory,
    workScheduleNegotiable: pin.post.workScheduleNegotiable ||
        WorkScheduleNegotiable.isLabel(pin.post.workSchedule),
  );

  if (flowResult == null || !context.mounted) return false;

  var missingCredentialLabels = const <String>[];
  if (pin.post.requiredCredentialIds.isNotEmpty) {
    final credentialResult = await showRequiredCredentialsApplyDialog(
      context,
      credentialIds: pin.post.requiredCredentialIds,
    );
    if (!credentialResult.proceed || !context.mounted) return false;
    missingCredentialLabels = CredentialCatalog.labelsForIds(
      credentialResult.missingCredentialIds,
    );
  }

  final shiftDateIso = flowResult.scheduleNegotiable
      ? ''
      : SelectedShiftDates.encode(flowResult.selectedDates);

  final phone = user.phone ?? '010-0000-0000';

  final requiredItems = pin.post.requiredResumeItems;
  List<ResumeItemKind> disclosedItems = const [];
  if (requiredItems.isNotEmpty) {
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    final resume = profile?.resume ?? const SeekerResumeContent();
    final disclosed = await showResumeDisclosureFlow(
      context,
      requiredItems: requiredItems,
      resume: resume,
      profile: profile,
    );
    if (disclosed == null || !context.mounted) return false;
    disclosedItems = disclosed.toList();
  }

  final heldCredentialIds = (AuthSession.instance.currentUser?.seekerProfile)
          ?.credentialHoldings
          .where((h) => h.isComplete)
          .map((h) => h.credentialId)
          .toList() ??
      const [];

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
    suggestedWorkDate: flowResult.primaryDate,
    hourlyWageText: pin.post.hourlyWage,
    employmentType: pin.post.employmentType,
    selectedShiftDate: shiftDateIso,
    shiftSlot: flowResult.shiftSlot,
    disclosedResumeItems: disclosedItems,
    requiredCredentialIds: pin.post.requiredCredentialIds,
    heldCredentialIds: heldCredentialIds,
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
      ),
    );
  }
  if (!context.mounted) return false;
  final credentialReminder = missingCredentialLabels.isEmpty
      ? ''
      : '\n\n필수 자격 확인: ${missingCredentialLabels.join(', ')}\n'
          '아직 등록하지 않았다면 이력서에서 자격증을 등록해 주세요.';
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 48),
      title: const Text('지원 완료'),
      content: Text(
        '「${pin.post.title}」에 지원했습니다.$credentialReminder\n\n기업의 연락을 기다려 주세요.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (missingCredentialLabels.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamed(AppRoutes.seekerMyCredentials);
            },
            child: const Text('지금 등록하기'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  onApplied?.call();
  return true;
}

String employmentTypeLabel(JobEmploymentType type) => type.label;
