import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/constants/labor_constants.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/local_branch_repository.dart';
import 'package:map/features/corporate/data/repositories/local_push_usage_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/services/push_job_post_payment_flow.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/services/registered_business_workplace_loader.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/presentation/navigation/push_base_point_args.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';
import 'package:map/core/widgets/korean_calendar.dart';
import 'package:map/features/corporate/domain/utils/daily_worker_policy.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_form.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_optional_services_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/resume_required_items_field.dart';
import 'package:map/features/credential/presentation/widgets/credential_search_picker.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';

/// 기업회원 — 수정할 공고 선택 (Speed Dial 2)
class CorporateSelectJobPostPage extends StatefulWidget {
  const CorporateSelectJobPostPage({super.key});

  @override
  State<CorporateSelectJobPostPage> createState() =>
      _CorporateSelectJobPostPageState();
}

class _CorporateSelectJobPostPageState extends State<CorporateSelectJobPostPage> {
  final _getPosts = const GetCorporateJobPostsUseCase(
    CorporateJobPostLocalDataSourceImpl(),
  );

  List<CorporateJobPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await _getPosts();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  void _openEdit(CorporateJobPost post) {
    Navigator.of(context)
        .pushNamed(AppRoutes.corporateEditJobPost, arguments: post)
        .then((updated) {
      if (!mounted) return;
      if (updated == true) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('수정할 공고 선택'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: _posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final post = _posts[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openEdit(post),
                    child: CorporateJobPostCard(post: post),
                  ),
                );
              },
            ),
    );
  }
}

/// 기업회원 — 공고 수정·복사
class CorporateEditJobPostPage extends StatefulWidget {
  const CorporateEditJobPostPage({
    super.key,
    required this.post,
    this.asCopy = false,
  });

  final CorporateJobPost post;
  final bool asCopy;

  @override
  State<CorporateEditJobPostPage> createState() =>
      _CorporateEditJobPostPageState();
}

class _CorporateEditJobPostPageState extends State<CorporateEditJobPostPage> {
  final _dataSource = const CorporateJobPostLocalDataSourceImpl();
  late final _updatePost = UpdateCorporateJobPostUseCase(_dataSource);
  late final _createPost = CreateCorporateJobPostUseCase(_dataSource);

  bool get _asCopy => widget.asCopy;

  late final TextEditingController _titleController =
      TextEditingController(text: widget.post.title);
  late JobPostDescriptionBody _descriptionBody =
      widget.post.effectiveDescriptionBody;
  late SalaryPayType _salaryPayType =
      parseSalaryPayType(widget.post.hourlyWage);
  late final TextEditingController _wageController = TextEditingController(
    text: LaborConstants.initialHourlyWageFieldText(
      salaryPayDigits(widget.post.hourlyWage),
    ),
  );
  late final TextEditingController _scheduleController =
      TextEditingController(text: widget.post.workSchedule);

  late WorkplaceAddress _workplace =
      WorkplaceAddress(roadAddress: widget.post.warehouseName);
  late DateTime? _paymentDate = widget.post.paymentDate;
  late SalaryPaymentMonthOffset? _paymentMonthOffset =
      widget.post.paymentMonthOffset;
  late int? _paymentDayOfMonth = widget.post.paymentDayOfMonth;
  late bool _paymentDateNegotiable = widget.post.paymentDateNegotiable;
  late bool _workPeriodNegotiable = widget.post.workPeriodNegotiable;
  late JobPostNotificationSettings? _notificationSettings =
      widget.post.notificationSettings;
  late CorporateJobPostStatus _status = _asCopy
      ? CorporateJobPostStatus.recruiting
      : widget.post.status;
  late WorkerCategory _workerCategory = widget.post.effectiveWorkerCategory;
  late String? _workCategoryId = widget.post.workCategoryId;
  bool _submitting = false;
  bool _loadingRegisteredWorkplace = false;
  final _registeredWorkplaceLoader = RegisteredBusinessWorkplaceLoader();
  late bool _dailyWorkerAcknowledged;
  List<CorporateBranch> _branches = [];
  CorporateBranch? _selectedBranch;
  late String? _shuttleRouteId = widget.post.commuteRouteId;
  late List<String> _linkedShuttleRouteIds =
      widget.post.effectiveLinkedCommuteRouteIds;
  late bool _hasShuttleRouteOverlay = widget.post.hasShuttleRouteOverlay;
  late Map<String, List<String>> _shuttleRegisteredStopIdsByRoute =
      Map<String, List<String>>.from(widget.post.shuttleRegisteredStopIdsByRoute);
  late List<ResumeItemKind> _requiredResumeItems =
      List<ResumeItemKind>.from(widget.post.requiredResumeItems);
  late List<String> _requiredCredentialIds =
      List<String>.from(widget.post.requiredCredentialIds);

  @override
  void initState() {
    super.initState();
    _dailyWorkerAcknowledged =
        widget.post.effectiveWorkerCategory == WorkerCategory.daily;
    _loadBranches();
    if (_asCopy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDarkTransientSnackBar(context, '공고가 복사되었습니다');
      });
    }
  }

  Future<void> _loadBranches() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final repo = await LocalBranchRepository.create();
    final branches = await repo.fetchForCompany(profile.companyKey);
    if (!mounted) return;
    CorporateBranch? selected;
    if (widget.post.branchId != null) {
      for (final b in branches) {
        if (b.id == widget.post.branchId) {
          selected = b;
          break;
        }
      }
    }
    setState(() {
      _branches = branches;
      _selectedBranch = selected;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _wageController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  Future<void> _searchWorkplace() async {
    final result = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
      arguments: _workplace.roadAddress,
    );
    if (result != null && mounted) {
      setState(() => _workplace = result);
    }
  }

  Future<void> _loadRegisteredWorkplace() async {
    setState(() => _loadingRegisteredWorkplace = true);
    final result = await _registeredWorkplaceLoader.load();
    if (!mounted) return;
    setState(() => _loadingRegisteredWorkplace = false);
    if (!result.isSuccess || result.workplace == null) {
      showTransientSnackBar(
        context,
        result.errorMessage ?? '사업장 소재지를 불러오지 못했습니다.',
      );
      return;
    }
    setState(() => _workplace = result.workplace!);
    final syncNote = result.headOfficeSynced
        ? ' 내정보 사업자 소재지도 함께 등록했습니다.'
        : '';
    showTransientSnackBar(
      context,
      '${result.sourceLabel}를 근무지에 적용했습니다.$syncNote',
    );
  }

  Future<void> _pickPaymentDate() async {
    final now = DateTime.now();
    final picked = await showKoreanDatePickerSheet(
      context,
      initialDate: _paymentDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      title: '급여지급일 선택',
    );
    if (picked != null && mounted) {
      setState(() {
        _paymentDate = picked;
        _paymentDateNegotiable = false;
      });
    }
  }

  SalaryPaymentSchedule? _buildPaymentSchedule() {
    if (_paymentDateNegotiable &&
        (_workerCategory.usesAbsolutePaymentDate ||
            _workerCategory.usesCalendarPaymentDate)) {
      return const SalaryPaymentSchedule.negotiable();
    }
    if (_workerCategory.usesAbsolutePaymentDate) {
      final dates = DailyWorkerPolicy.paymentDatesFromWorkSchedule(
        _scheduleController.text,
      );
      if (dates.isEmpty) return null;
      return SalaryPaymentSchedule.dailyPerWorkDay(dates);
    }
    if (_workerCategory.usesCalendarPaymentDate) {
      if (_paymentDate == null) return null;
      return SalaryPaymentSchedule.absoluteDate(_paymentDate!);
    }
    if (_workerCategory.usesMonthlyPaymentDate) {
      if (_paymentMonthOffset == null || _paymentDayOfMonth == null) {
        return null;
      }
      return SalaryPaymentSchedule.monthlyRule(
        monthOffset: _paymentMonthOffset!,
        dayOfMonth: _paymentDayOfMonth!,
      );
    }
    return null;
  }

  Future<void> _onWorkerCategoryChanged(WorkerCategory category) async {
    if (category == WorkerCategory.daily && !_dailyWorkerAcknowledged) {
      final ok = await DailyWorkerPolicy.showAcknowledgmentDialog(context);
      if (!ok || !mounted) return;
      setState(() => _dailyWorkerAcknowledged = true);
    }
    if (!mounted) return;
    setState(() {
      _workerCategory = category;
      if (category.usesAbsolutePaymentDate) {
        _paymentMonthOffset = null;
        _paymentDayOfMonth = null;
      } else if (category.usesCalendarPaymentDate) {
        _paymentMonthOffset = null;
        _paymentDayOfMonth = null;
      } else if (category.usesMonthlyPaymentDate) {
        _paymentDate = null;
        _paymentDateNegotiable = false;
        _dailyWorkerAcknowledged = false;
      } else {
        _paymentDate = null;
        _paymentDateNegotiable = false;
        _dailyWorkerAcknowledged = false;
      }
      if (!category.usesFirstStartDateOnly) {
        _workPeriodNegotiable = false;
      }
    });
  }

  void _syncDailyPaymentDateFromSchedule() {
    if (!mounted) return;
    setState(() => _paymentDateNegotiable = false);
  }

  Future<void> _configurePushNotification() async {
    final result =
        await Navigator.of(context).pushNamed<JobPostNotificationSettings>(
      AppRoutes.corporatePushBasePoint,
      arguments: PushBasePointArgs(
        initialSettings: _notificationSettings,
        workplace: _workplace,
      ),
    );
    if (result != null && mounted) {
      setState(() => _notificationSettings = result);
    }
  }

  Future<void> _openPaidServices() async {
    final fresh = await const CorporateJobPostLocalDataSourceImpl()
        .findById(widget.post.id);
    if (!mounted) return;
    await showCorporateJobPostOptionalServicesSheet(
      context,
      post: fresh ?? widget.post,
      workplace: _workplace,
      onPostUpdated: (updated) {
        if (!mounted) return;
        setState(() {
          _notificationSettings = updated.notificationSettings;
          _linkedShuttleRouteIds = updated.effectiveLinkedCommuteRouteIds;
          _shuttleRouteId = _linkedShuttleRouteIds.isNotEmpty
              ? _linkedShuttleRouteIds.first
              : null;
          _hasShuttleRouteOverlay = updated.hasShuttleRouteOverlay;
          _shuttleRegisteredStopIdsByRoute =
              Map<String, List<String>>.from(
            updated.shuttleRegisteredStopIdsByRoute,
          );
        });
      },
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_scheduleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무 일·시간을 선택해 주세요.')),
      );
      return;
    }
    if (_workerCategory.usesFirstStartDateOnly) {
      final spec = WorkScheduleCodec.tryParse(_scheduleController.text);
      if (spec == null ||
          !spec.isCompleteFor(workPeriodNegotiable: _workPeriodNegotiable)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('근무 일·시간을 선택해 주세요.')),
        );
        return;
      }
    } else if (_workerCategory.usesWorkPeriodWithEndDate) {
      final spec = WorkScheduleCodec.tryParse(_scheduleController.text);
      if (spec == null || !spec.isCompleteFor()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('근무 시작일과 종료일을 선택해 주세요.')),
        );
        return;
      }
    }

    final paymentSchedule = _buildPaymentSchedule();
    if (paymentSchedule == null || !paymentSchedule.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('급여지급일을 선택해 주세요.')),
      );
      return;
    }

    if (_branches.isNotEmpty && _selectedBranch == null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('지점 미지정'),
          content: const Text(
            '지점을 지정하지 않으면 Multi-지점 ROI·출근 집계가 부정확합니다.\n'
            '그래도 저장하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('지점 선택'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('미지정 저장'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);

    final registeredBy = AuthSession.instance.currentUser?.corporateProfile;
    var notificationSettings = _notificationSettings;
    JobPostPaymentRecord? paymentRecord;
    var extraPushFeeKrw = 0;

    final paymentOutcome = await PushJobPostPaymentFlow().collect(
      context: context,
      notificationSettings: notificationSettings,
      profile: registeredBy,
      companyKey: registeredBy?.companyKey,
    );
    if (!mounted) return;
    if (paymentOutcome == null) {
      setState(() => _submitting = false);
      return;
    }
    notificationSettings = paymentOutcome.notificationSettings;
    paymentRecord = paymentOutcome.paymentRecord ?? widget.post.paymentRecord;
    extraPushFeeKrw = paymentOutcome.extraPushFeeKrw;
    setState(() => _notificationSettings = notificationSettings);

    final wageLabel = _salaryPayType.formatAmount(_wageController.text);
    final CorporateJobPostResult result;
    if (_asCopy) {
      result = await _createPost(
        title: _titleController.text,
        workplace: _workplace,
        hourlyWage: wageLabel,
        workSchedule: _scheduleController.text,
        descriptionBody: _descriptionBody,
        paymentSchedule: paymentSchedule,
        workerCategory: _workerCategory,
        workPeriodNegotiable: _workPeriodNegotiable,
        workCategoryId: _workCategoryId,
        employmentType: _workerCategory.employmentType,
        notificationSettings: notificationSettings,
        registeredBy: registeredBy,
        paymentRecord: paymentRecord,
        branchId: _selectedBranch?.id,
        branchName: _selectedBranch?.name,
        commuteRouteId: _shuttleRouteId,
        linkedCommuteRouteIds: _linkedShuttleRouteIds,
        hasShuttleRouteOverlay: _linkedShuttleRouteIds.isEmpty
            ? false
            : _hasShuttleRouteOverlay,
        requiredResumeItems: _requiredResumeItems,
        requiredCredentialIds: _requiredCredentialIds,
      );
    } else {
      result = await _updatePost(
        original: widget.post.copyWith(
          commuteRouteId: _shuttleRouteId,
          linkedCommuteRouteIds: _linkedShuttleRouteIds,
          shuttleRegisteredStopIdsByRoute: _shuttleRegisteredStopIdsByRoute,
          hasShuttleRouteOverlay: _linkedShuttleRouteIds.isEmpty
              ? false
              : _hasShuttleRouteOverlay,
        ),
        title: _titleController.text,
        workplace: _workplace,
        hourlyWage: wageLabel,
        workSchedule: _scheduleController.text,
        descriptionBody: _descriptionBody,
        paymentSchedule: paymentSchedule,
        workerCategory: _workerCategory,
        workPeriodNegotiable: _workPeriodNegotiable,
        workCategoryId: _workCategoryId,
        status: _status,
        notificationSettings: notificationSettings,
        paymentRecord: paymentRecord,
        branchId: _selectedBranch?.id,
        branchName: _selectedBranch?.name,
        commuteRouteId: _shuttleRouteId,
        linkedCommuteRouteIds: _linkedShuttleRouteIds,
        hasShuttleRouteOverlay: _linkedShuttleRouteIds.isEmpty
            ? false
            : _hasShuttleRouteOverlay,
        requiredResumeItems: _requiredResumeItems,
        requiredCredentialIds: _requiredCredentialIds,
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      final message = result.message ?? '수정에 실패했습니다.';
      final needsHeadOffice = message.contains('본사 주소');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: needsHeadOffice
              ? SnackBarAction(
                  label: '내정보에서 등록',
                  onPressed: () => Navigator.of(context)
                      .pushNamed(AppRoutes.corporateMyInfo),
                )
              : null,
        ),
      );
      return;
    }

    if (extraPushFeeKrw > 0 && registeredBy != null) {
      final usageRepo = await LocalPushUsageRepository.create();
      await usageRepo.recordDispatch(
        companyKey: registeredBy.companyKey,
        paymentKrw: extraPushFeeKrw,
      );
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(_asCopy ? '공고 복사' : '일자리 수정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: CorporateJobPostForm(
          titleController: _titleController,
          descriptionBody: _descriptionBody,
          onDescriptionBodyChanged: (body) =>
              setState(() => _descriptionBody = body),
          wageController: _wageController,
          scheduleController: _scheduleController,
          workplace: _workplace,
          onSearchWorkplace: _searchWorkplace,
          onLoadRegisteredWorkplace: _loadRegisteredWorkplace,
          loadingRegisteredWorkplace: _loadingRegisteredWorkplace,
          workerCategory: _workerCategory,
          onWorkerCategoryChanged: _onWorkerCategoryChanged,
          workCategoryId: _workCategoryId,
          onWorkCategoryChanged: (id) => setState(() => _workCategoryId = id),
          salaryPayType: _salaryPayType,
          onSalaryPayTypeChanged: (type) =>
              setState(() => _salaryPayType = type),
          paymentDate: _paymentDate,
          onPickPaymentDate: _pickPaymentDate,
          paymentMonthOffset: _paymentMonthOffset,
          paymentDayOfMonth: _paymentDayOfMonth,
          onPaymentMonthOffsetChanged: (value) =>
              setState(() => _paymentMonthOffset = value),
          onPaymentDayOfMonthChanged: (value) =>
              setState(() => _paymentDayOfMonth = value),
          notificationSettings: _notificationSettings,
          onConfigurePushNotification: _configurePushNotification,
          showExposureSection: false,
          submitLabel: _asCopy ? '복사 등록' : '수정 저장',
          submitting: _submitting,
          onSubmit: _submit,
          dailyWorkerAcknowledged: _dailyWorkerAcknowledged,
          onDailyScheduleCommitted: _syncDailyPaymentDateFromSchedule,
          paymentDateNegotiable: _paymentDateNegotiable,
          onPaymentDateNegotiableChanged: (value) =>
              setState(() => _paymentDateNegotiable = value),
          workPeriodNegotiable: _workPeriodNegotiable,
          onWorkPeriodNegotiableChanged: (value) =>
              setState(() => _workPeriodNegotiable = value),
          beforeSubmit: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResumeRequiredItemsField(
                selected: _requiredResumeItems,
                onChanged: (value) =>
                    setState(() => _requiredResumeItems = value),
              ),
              const SizedBox(height: 16),
              RequiredCredentialsField(
                selectedIds: _requiredCredentialIds,
                onChanged: (value) =>
                    setState(() => _requiredCredentialIds = value),
              ),
              const SizedBox(height: 16),
              if (!_asCopy) ...[
                const FieldLabel('공고 상태'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.searchBarBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CorporateJobPostStatus>(
                      isExpanded: true,
                      value: _status,
                      items: CorporateJobPostStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                  ),
                ),
              ],
              if (_branches.isNotEmpty) ...[
                const SizedBox(height: 16),
                if (_selectedBranch == null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '지점 미지정 시 ROI·출근 데이터가 본사 단위로만 집계됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                DropdownButtonFormField<CorporateBranch?>(
                  value: _selectedBranch,
                  decoration: const InputDecoration(
                    labelText: '연결 지점 (선택)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<CorporateBranch?>(
                      value: null,
                      child: Text('지점 미지정'),
                    ),
                    ..._branches.map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.displayLabel),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedBranch = value),
                ),
              ],
            ],
          ),
          afterSubmit: !_asCopy
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _openPaidServices,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('유료 서비스 (알림핀·정류장·결제)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
