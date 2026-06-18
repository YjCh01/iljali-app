import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/labor_constants.dart';
import 'package:map/core/job_board/job_board_refresh.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/local_branch_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/core/widgets/korean_calendar.dart';
import 'package:map/features/corporate/domain/utils/daily_worker_policy.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_published_args.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_form.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 일자리 등록 — 최종 작성·저장
class CorporateJobPostWritePage extends StatefulWidget {
  const CorporateJobPostWritePage({
    super.key,
    this.draft = const JobPostWriteDraft(),
  });

  final JobPostWriteDraft draft;

  @override
  State<CorporateJobPostWritePage> createState() =>
      _CorporateJobPostWritePageState();
}

class _CorporateJobPostWritePageState extends State<CorporateJobPostWritePage> {
  final _dataSource = const CorporateJobPostLocalDataSourceImpl();
  late final _createPost = CreateCorporateJobPostUseCase(_dataSource);

  late final TextEditingController _titleController =
      TextEditingController(text: widget.draft.title);
  late final TextEditingController _jobDescriptionController =
      TextEditingController(text: widget.draft.jobDescription);
  late final TextEditingController _wageController =
      TextEditingController(
    text: LaborConstants.initialHourlyWageFieldText(
      salaryPayDigits(widget.draft.hourlyWage),
    ),
  );
  late final TextEditingController _scheduleController =
      TextEditingController(text: widget.draft.workSchedule);

  WorkplaceAddress? _workplace;
  DateTime? _paymentDate;
  SalaryPaymentMonthOffset? _paymentMonthOffset;
  int? _paymentDayOfMonth;
  WorkerCategory _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
  String? _workCategoryId;
  SalaryPayType _salaryPayType = SalaryPayType.hourly;
  bool _submitting = false;
  bool _dailyWorkerAcknowledged = false;
  bool _paymentDateNegotiable = false;
  List<CorporateBranch> _branches = [];
  CorporateBranch? _selectedBranch;

  @override
  void initState() {
    super.initState();
    if (widget.draft.workplaceAddress != null) {
      _workplace = WorkplaceAddress(roadAddress: widget.draft.workplaceAddress!);
    }
    _paymentDate = widget.draft.paymentDate;
    _paymentMonthOffset = widget.draft.paymentMonthOffset;
    _paymentDayOfMonth = widget.draft.paymentDayOfMonth;
    _workerCategory = widget.draft.workerCategory;
    _workCategoryId = widget.draft.workCategoryId;
    if (!ProductFeatureFlags.isWorkerCategoryAllowed(_workerCategory)) {
      _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
    }
    _salaryPayType = parseSalaryPayType(widget.draft.hourlyWage);
    _loadBranches();
    if (_workerCategory == WorkerCategory.daily) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDailyWorkerAcknowledged();
      });
    }
  }

  Future<void> _ensureDailyWorkerAcknowledged() async {
    if (_dailyWorkerAcknowledged || !mounted) return;
    final ok = await DailyWorkerPolicy.showAcknowledgmentDialog(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _dailyWorkerAcknowledged = true);
    } else {
      setState(() {
        _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
      });
    }
  }

  void _syncDailyPaymentDateFromSchedule() {
    if (!mounted) return;
    setState(() => _paymentDateNegotiable = false);
  }

  Future<void> _loadBranches() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final repo = await LocalBranchRepository.create();
    final branches = await repo.fetchForCompany(profile.companyKey);
    if (!mounted) return;
    setState(() => _branches = branches);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _jobDescriptionController.dispose();
    _wageController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  Future<void> _searchWorkplace() async {
    final result = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
      arguments: _workplace?.roadAddress,
    );
    if (result != null && mounted) {
      setState(() => _workplace = result);
    }
  }

  Future<void> _pickPaymentDate() async {
    final now = DateTime.now();
    final picked = await showKoreanDatePickerSheet(
      context,
      initialDate: _paymentDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
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
    if (_paymentMonthOffset == null || _paymentDayOfMonth == null) {
      return null;
    }
    return SalaryPaymentSchedule.monthlyRule(
      monthOffset: _paymentMonthOffset!,
      dayOfMonth: _paymentDayOfMonth!,
    );
  }

  Future<void> _onWorkerCategoryChanged(WorkerCategory category) async {
    if (category == WorkerCategory.daily && !_dailyWorkerAcknowledged) {
      final ok = await DailyWorkerPolicy.showAcknowledgmentDialog(context);
      if (!ok || !mounted) return;
      setState(() => _dailyWorkerAcknowledged = true);
    } else if (category != WorkerCategory.daily) {
      setState(() => _dailyWorkerAcknowledged = false);
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
      } else {
        _paymentDate = null;
        _paymentDateNegotiable = false;
      }
    });
  }

  Future<void> _openImportPage() async {
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateJobPostImport,
    );
    if (created == true && mounted) {
      Navigator.of(context).pop(
        const CorporateJobPostFlowResult(shellTabIndex: 1),
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_workplace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무지를 검색해 주세요.')),
      );
      return;
    }
    if (_scheduleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무 일·시간을 선택해 주세요.')),
      );
      return;
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
            '그래도 등록하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('지점 선택'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('미지정 등록'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);

    final registeredBy = AuthSession.instance.currentUser?.corporateProfile;
    final wageLabel = _salaryPayType.formatAmount(_wageController.text);
    final result = await _createPost(
      title: _titleController.text,
      workplace: _workplace!,
      hourlyWage: wageLabel,
      workSchedule: _scheduleController.text,
      jobDescription: _jobDescriptionController.text,
      summary: _jobDescriptionController.text,
      paymentSchedule: paymentSchedule,
      workerCategory: _workerCategory,
      workCategoryId: _workCategoryId,
      registeredBy: registeredBy,
      branchId: _selectedBranch?.id,
      branchName: _selectedBranch?.name,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      final message = result.message ?? '등록에 실패했습니다.';
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

    if (result.post == null) return;
    JobBoardRefresh.markUpdated();
    final flowResult =
        await Navigator.of(context).pushNamed<CorporateJobPostFlowResult>(
      AppRoutes.corporateJobPostPublished,
      arguments: CorporateJobPostPublishedArgs(
        post: result.post!,
        workplace: _workplace!,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      flowResult ?? const CorporateJobPostFlowResult(shellTabIndex: 1),
    );
  }

  Widget? _buildBeforeSubmit() => _buildBranchSection();

  Widget? _buildBranchSection() {
    if (_branches.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          onChanged: (value) => setState(() => _selectedBranch = value),
        ),
      ],
    );
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
        title: const Text('일자리 내용 작성'),
        actions: [
          if (widget.draft.importSourceLabel == null)
            TextButton(
              onPressed: _openImportPage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AiSparkleMark(
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    JobPostImportCopy.pageTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.draft.importSourceLabel != null) ...[
              Material(
                color: AppColors.primaryLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.draft.importSourceLabel} · 초안이 채워졌습니다. 등록 전 확인해 주세요.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            CorporateJobPostForm(
          titleController: _titleController,
          jobDescriptionController: _jobDescriptionController,
          wageController: _wageController,
          scheduleController: _scheduleController,
          workplace: _workplace,
          onSearchWorkplace: _searchWorkplace,
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
          notificationSettings: null,
          onConfigurePushNotification: () {},
          showExposureSection: false,
          submitLabel: '일자리 등록하기',
          submitting: _submitting,
          onSubmit: _submit,
          dailyWorkerAcknowledged: _dailyWorkerAcknowledged,
          onDailyScheduleCommitted: _syncDailyPaymentDateFromSchedule,
          paymentDateNegotiable: _paymentDateNegotiable,
          onPaymentDateNegotiableChanged: (value) =>
              setState(() => _paymentDateNegotiable = value),
          beforeSubmit: _buildBeforeSubmit(),
            ),
          ],
        ),
      ),
    );
  }
}
