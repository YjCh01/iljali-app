import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/constants/labor_constants.dart';
import 'package:map/core/job_board/job_board_refresh.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/korean_calendar.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/local_branch_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/services/registered_business_workplace_loader.dart';
import 'package:map/features/corporate/domain/services/workplace_address_resolver.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:map/features/corporate/domain/utils/daily_worker_policy.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_published_args.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_form.dart';
import 'package:map/features/corporate/presentation/widgets/resume_required_items_field.dart';
import 'package:map/features/credential/presentation/widgets/credential_search_picker.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';

/// 일자리 직접 작성 폼 — 등록·가져오기 화면 공통
class CorporateJobPostWriteFormHost extends StatefulWidget {
  const CorporateJobPostWriteFormHost({
    super.key,
    this.initialDraft = const JobPostWriteDraft(),
    this.onFlowComplete,
    this.submitLabel = '일자리 등록하기',
  });

  final JobPostWriteDraft initialDraft;
  final ValueChanged<CorporateJobPostFlowResult>? onFlowComplete;
  final String submitLabel;

  @override
  CorporateJobPostWriteFormHostState createState() =>
      CorporateJobPostWriteFormHostState();
}

class CorporateJobPostWriteFormHostState
    extends State<CorporateJobPostWriteFormHost> {
  final _dataSource = const CorporateJobPostLocalDataSourceImpl();
  late final _createPost = CreateCorporateJobPostUseCase(_dataSource);

  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialDraft.title);
  late JobPostDescriptionBody _descriptionBody =
      _initialDescriptionBody(widget.initialDraft);
  late final TextEditingController _wageController = TextEditingController(
    text: LaborConstants.initialHourlyWageFieldText(
      salaryPayDigits(widget.initialDraft.hourlyWage),
    ),
  );
  late final TextEditingController _scheduleController =
      TextEditingController(text: widget.initialDraft.workSchedule);

  WorkplaceAddress? _workplace;
  DateTime? _paymentDate;
  SalaryPaymentMonthOffset? _paymentMonthOffset;
  int? _paymentDayOfMonth;
  WorkerCategory _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
  String? _workCategoryId;
  SalaryPayType _salaryPayType = SalaryPayType.hourly;
  bool _submitting = false;
  bool _loadingRegisteredWorkplace = false;
  final _registeredWorkplaceLoader = RegisteredBusinessWorkplaceLoader();
  bool _paymentDateNegotiable = false;
  bool _workScheduleNegotiable = false;
  List<CorporateBranch> _branches = [];
  CorporateBranch? _selectedBranch;
  List<ResumeItemKind> _requiredResumeItems = const [];
  List<String> _requiredCredentialIds = const [];
  String? _importSourceLabel;

  static JobPostDescriptionBody _initialDescriptionBody(JobPostWriteDraft draft) {
    if (draft.descriptionBody.hasContent) return draft.descriptionBody;
    final text = draft.jobDescription.trim();
    if (text.isNotEmpty) return JobPostDescriptionBody(text: text);
    return const JobPostDescriptionBody();
  }

  @override
  void initState() {
    super.initState();
    _applyDraft(widget.initialDraft, notify: false);
    _loadBranches();
  }

  /// 가져오기 결과 등으로 폼 필드를 채웁니다.
  void applyDraft(JobPostWriteDraft draft) {
    _applyDraft(draft, notify: true);
  }

  /// 근무지 텍스트가 있으면 검색·지오코딩까지 시도합니다.
  Future<void> applyDraftAsync(JobPostWriteDraft draft) async {
    _applyDraft(draft, notify: false);
    final raw = draft.workplaceAddress?.trim();
    if (raw != null && raw.isNotEmpty) {
      final resolved = await WorkplaceAddressResolver.resolve(raw);
      if (resolved != null && mounted) {
        setState(() => _workplace = resolved);
      }
    }
    if (mounted) setState(() {});
  }

  void _applyDraft(JobPostWriteDraft draft, {required bool notify}) {
    _titleController.text = draft.title;
    _descriptionBody = _initialDescriptionBody(draft);
    _wageController.text = LaborConstants.initialHourlyWageFieldText(
      salaryPayDigits(draft.hourlyWage),
    );
    _scheduleController.text = draft.workSchedule;
    _workplace = draft.workplaceAddress != null
        ? WorkplaceAddress(roadAddress: draft.workplaceAddress!)
        : null;
    _paymentDate = draft.paymentDate;
    _paymentMonthOffset = draft.paymentMonthOffset;
    _paymentDayOfMonth = draft.paymentDayOfMonth;
    _workerCategory = draft.workerCategory;
    _workCategoryId = draft.workCategoryId;
    _workScheduleNegotiable = draft.workScheduleNegotiable ||
        draft.workPeriodNegotiable ||
        WorkScheduleNegotiable.isLabel(draft.workSchedule);
    _requiredResumeItems = List<ResumeItemKind>.from(draft.requiredResumeItems);
    _requiredCredentialIds = List<String>.from(draft.requiredCredentialIds);
    _importSourceLabel = draft.importSourceLabel;
    if (!ProductFeatureFlags.isWorkerCategoryAllowed(_workerCategory)) {
      _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
    }
    _salaryPayType = parseSalaryPayType(draft.hourlyWage);
    if (notify) {
      setState(() {});
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

  Future<void> _loadRegisteredWorkplace() async {
    setState(() => _loadingRegisteredWorkplace = true);
    final result = await _registeredWorkplaceLoader.load();
    if (!mounted) return;
    setState(() => _loadingRegisteredWorkplace = false);
    if (!result.isSuccess || result.workplace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? '사업장 소재지를 불러오지 못했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _workplace = result.workplace);
    final syncNote =
        result.headOfficeSynced ? ' 내정보 사업자 소재지도 함께 등록했습니다.' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.sourceLabel}를 근무지에 적용했습니다.$syncNote',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  SalaryPaymentSchedule? _buildPaymentSchedule() => buildSalaryPaymentSchedule(
        workerCategory: _workerCategory,
        workScheduleNegotiable: _workScheduleNegotiable,
        paymentDateNegotiable: _paymentDateNegotiable,
        workScheduleRaw: _scheduleController.text,
        paymentDate: _paymentDate,
        paymentMonthOffset: _paymentMonthOffset,
        paymentDayOfMonth: _paymentDayOfMonth,
      );

  Future<void> _onWorkerCategoryChanged(WorkerCategory category) async {
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
      } else {
        _paymentDate = null;
        _paymentDateNegotiable = false;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_workplace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무지를 검색해 주세요.')),
      );
      return;
    }
    if (!_workScheduleNegotiable && _scheduleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무 일·시간을 선택해 주세요.')),
      );
      return;
    }
    if (!_workScheduleNegotiable && _workerCategory.usesFirstStartDateOnly) {
      final spec = WorkScheduleCodec.tryParse(_scheduleController.text);
      if (spec == null ||
          !spec.isCompleteFor(workScheduleNegotiable: _workScheduleNegotiable)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('근무 일·시간을 선택해 주세요.')),
        );
        return;
      }
    } else if (!_workScheduleNegotiable &&
        _workerCategory.usesWorkPeriodWithEndDate) {
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
      descriptionBody: _descriptionBody,
      paymentSchedule: paymentSchedule,
      workerCategory: _workerCategory,
      workPeriodNegotiable:
          _workScheduleNegotiable && _workerCategory.usesFirstStartDateOnly,
      workScheduleNegotiable: _workScheduleNegotiable,
      workCategoryId: _workCategoryId,
      registeredBy: registeredBy,
      branchId: _selectedBranch?.id,
      branchName: _selectedBranch?.name,
      requiredResumeItems: _requiredResumeItems,
      requiredCredentialIds: _requiredCredentialIds,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '등록에 실패했습니다.'),
          behavior: SnackBarBehavior.floating,
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
    final completed =
        flowResult ?? const CorporateJobPostFlowResult(shellTabIndex: 1);
    if (widget.onFlowComplete != null) {
      widget.onFlowComplete!(completed);
    } else {
      Navigator.of(context).pop(completed);
    }
  }

  Widget _buildBeforeSubmit() {
    final branch = _buildBranchSection();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResumeRequiredItemsField(
          selected: _requiredResumeItems,
          onChanged: (value) => setState(() => _requiredResumeItems = value),
        ),
        const SizedBox(height: 16),
        RequiredCredentialsField(
          selectedIds: _requiredCredentialIds,
          onChanged: (value) => setState(() => _requiredCredentialIds = value),
        ),
        if (branch != null) ...[
          const SizedBox(height: 16),
          branch,
        ],
      ],
    );
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_importSourceLabel != null) ...[
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
                      '$_importSourceLabel · 아래 항목을 확인·수정한 뒤 등록해 주세요.',
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
          notificationSettings: null,
          onConfigurePushNotification: () {},
          showExposureSection: false,
          submitLabel: widget.submitLabel,
          submitting: _submitting,
          onSubmit: _submit,
          onDailyScheduleCommitted: _syncDailyPaymentDateFromSchedule,
          paymentDateNegotiable:
              _paymentDateNegotiable || _workScheduleNegotiable,
          onPaymentDateNegotiableChanged: (value) =>
              setState(() => _paymentDateNegotiable = value),
          workScheduleNegotiable: _workScheduleNegotiable,
          onWorkScheduleNegotiableChanged: (value) => setState(() {
            _workScheduleNegotiable = value;
            if (value &&
                (_workerCategory.usesAbsolutePaymentDate ||
                    _workerCategory.usesCalendarPaymentDate)) {
              _paymentDateNegotiable = true;
            }
          }),
          beforeSubmit: _buildBeforeSubmit(),
        ),
      ],
    );
  }
}
