import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/job_board/job_board_refresh.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/local_branch_repository.dart';
import 'package:map/features/corporate/data/repositories/local_push_usage_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/internal_approval_report.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/services/push_job_post_payment_flow.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/core/widgets/korean_calendar.dart';
import 'package:map/features/corporate/presentation/widgets/push_registration_cost_banner.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_form.dart';

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
    text: salaryPayDigits(widget.draft.hourlyWage),
  );
  late final TextEditingController _scheduleController =
      TextEditingController(text: widget.draft.workSchedule);
  late final TextEditingController _summaryController =
      TextEditingController(text: widget.draft.summary);

  WorkplaceAddress? _workplace;
  DateTime? _paymentDate;
  SalaryPaymentMonthOffset? _paymentMonthOffset;
  int? _paymentDayOfMonth;
  JobPostNotificationSettings? _notificationSettings;
  EmployerPushWallet? _wallet;
  WorkerCategory _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
  SalaryPayType _salaryPayType = SalaryPayType.hourly;
  bool _submitting = false;
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
    _notificationSettings = widget.draft.notificationSettings;
    _workerCategory = widget.draft.workerCategory;
    if (!ProductFeatureFlags.isWorkerCategoryAllowed(_workerCategory)) {
      _workerCategory = ProductFeatureFlags.defaultWorkerCategory;
    }
    _salaryPayType = parseSalaryPayType(widget.draft.hourlyWage);
    _loadBranches();
    _refreshWallet();
  }

  Future<void> _refreshWallet() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (mounted) setState(() => _wallet = wallet);
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
    _summaryController.dispose();
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
      setState(() => _paymentDate = picked);
    }
  }

  SalaryPaymentSchedule? _buildPaymentSchedule() {
    if (_workerCategory == WorkerCategory.daily) {
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

  void _onWorkerCategoryChanged(WorkerCategory category) {
    setState(() {
      _workerCategory = category;
      if (category == WorkerCategory.daily) {
        _paymentMonthOffset = null;
        _paymentDayOfMonth = null;
      } else {
        _paymentDate = null;
      }
    });
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
      await _refreshWallet();
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

    var notificationSettings = _notificationSettings;
    JobPostPaymentRecord? paymentRecord;
    var extraPushFeeKrw = 0;
    final registeredBy = AuthSession.instance.currentUser?.corporateProfile;

    if (registeredBy != null && notificationSettings != null) {
      final wallet = await PushWalletService().loadWallet(registeredBy);
      notificationSettings = PushWalletCreditPolicy.clampNotificationSettings(
        notificationSettings!,
        wallet,
      );
      setState(() => _notificationSettings = notificationSettings);
    }

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
    paymentRecord = paymentOutcome.paymentRecord;
    extraPushFeeKrw = paymentOutcome.extraPushFeeKrw;
    setState(() => _notificationSettings = notificationSettings);

    final wageLabel = _salaryPayType.formatAmount(_wageController.text);
    final result = await _createPost(
      title: _titleController.text,
      workplace: _workplace!,
      hourlyWage: wageLabel,
      workSchedule: _scheduleController.text,
      jobDescription: _jobDescriptionController.text,
      summary: _summaryController.text,
      paymentSchedule: paymentSchedule,
      workerCategory: _workerCategory,
      notificationSettings: notificationSettings,
      registeredBy: registeredBy,
      paymentRecord: paymentRecord,
      branchId: _selectedBranch?.id,
      branchName: _selectedBranch?.name,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '등록에 실패했습니다.')),
      );
      return;
    }

    if (mounted) {
      await _showGoldenPinUpsell();
    }

    if (paymentRecord != null && result.post != null && registeredBy != null) {
      await Navigator.of(context).pushNamed<bool>(
        AppRoutes.corporateInternalApprovalReport,
        arguments: InternalApprovalReport(
          profile: registeredBy,
          post: result.post!,
          paymentRecord: paymentRecord,
        ),
      );
    } else if (paymentRecord != null && registeredBy == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '기업·담당자 정보가 없어 결재 보고서를 건너뛰었습니다. 홈에서 등록해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final pushTier = paymentOutcome.dispatchRadiusTier ??
        notificationSettings?.primaryBase?.radiusTier;
    if (pushTier != null && pushTier != PushRadiusTier.radius0km) {
      final slotCount = paymentOutcome.recruitmentPushCount > 0
          ? paymentOutcome.recruitmentPushCount
          : 1;
      await Navigator.of(context).pushNamed<bool>(
        AppRoutes.corporatePushDispatch,
        arguments: PushDispatchArgs(
          radiusTier: pushTier,
          recruitmentSlotCount: slotCount,
          jobPostId: result.post?.id,
          jobTitle: result.post?.title,
          companyName: registeredBy?.companyName,
        ),
      );
      if (registeredBy != null) {
        final usageRepo = await LocalPushUsageRepository.create();
        await usageRepo.recordDispatch(
          companyKey: registeredBy.companyKey,
          paymentKrw: extraPushFeeKrw,
        );
      }
    }

    if (!mounted) return;
    JobBoardRefresh.markUpdated();
    Navigator.of(context).pop(true);
  }

  Future<void> _showGoldenPinUpsell() async {
    final goShop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('공고 등록 완료'),
        content: Text(
          '공고가 무료로 등록되었습니다.\n'
          '사업자번호당 동시 활성 공고는 최대 10개입니다.\n'
          '근무지 ${PushPackageCatalog.pushRadiusLabel} · 하루 1회 무료 푸시로 지원자를 모집해 보세요.\n\n'
          '더 넓은 지역에 알리려면 지역 푸시권을 구매하세요. '
          '(${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}/회)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('지역 푸시권 보기'),
          ),
        ],
      ),
    );
    if (goShop == true && mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.corporatePushPackageShop);
    }
  }

  Widget? _buildBeforeSubmit() {
    final children = <Widget>[];
    final settings = _notificationSettings;
    final wallet = _wallet;
    if (settings?.hasConfiguredBase == true && wallet != null) {
      children.add(
        PushRegistrationCostBanner(settings: settings!, wallet: wallet),
      );
      children.add(const SizedBox(height: 16));
    }

    if (_branches.isNotEmpty) {
      if (_selectedBranch == null) {
        children.add(
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
        );
      }
      children.add(
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
      );
      children.add(const SizedBox(height: 16));
    }

    if (children.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: CorporateJobPostForm(
          titleController: _titleController,
          jobDescriptionController: _jobDescriptionController,
          wageController: _wageController,
          scheduleController: _scheduleController,
          summaryController: _summaryController,
          workplace: _workplace,
          onSearchWorkplace: _searchWorkplace,
          workerCategory: _workerCategory,
          onWorkerCategoryChanged: _onWorkerCategoryChanged,
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
          submitLabel: '일자리 등록하기',
          submitting: _submitting,
          onSubmit: _submit,
          beforeSubmit: _buildBeforeSubmit(),
        ),
      ),
    );
  }
}

/// 푸시 거점 페이지 라우트 인자
class PushBasePointArgs {
  const PushBasePointArgs({
    this.initialSettings,
    this.workplace,
  });

  final JobPostNotificationSettings? initialSettings;
  final WorkplaceAddress? workplace;
}
