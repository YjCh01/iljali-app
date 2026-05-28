import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
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
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_write_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_form.dart';

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
                return CorporateJobPostCard(
                  post: post,
                  onTap: () => _openEdit(post),
                );
              },
            ),
    );
  }
}

/// 기업회원 — 공고 수정
class CorporateEditJobPostPage extends StatefulWidget {
  const CorporateEditJobPostPage({
    super.key,
    required this.post,
  });

  final CorporateJobPost post;

  @override
  State<CorporateEditJobPostPage> createState() =>
      _CorporateEditJobPostPageState();
}

class _CorporateEditJobPostPageState extends State<CorporateEditJobPostPage> {
  final _dataSource = const CorporateJobPostLocalDataSourceImpl();
  late final _updatePost = UpdateCorporateJobPostUseCase(_dataSource);

  late final TextEditingController _titleController =
      TextEditingController(text: widget.post.title);
  late final TextEditingController _jobDescriptionController =
      TextEditingController(
    text: widget.post.jobDescription.isNotEmpty
        ? widget.post.jobDescription
        : widget.post.summary,
  );
  late final TextEditingController _wageController = TextEditingController(
    text: salaryPayDigits(widget.post.hourlyWage),
  );
  late final TextEditingController _scheduleController =
      TextEditingController(text: widget.post.workSchedule);
  late final TextEditingController _summaryController =
      TextEditingController();

  late WorkplaceAddress _workplace =
      WorkplaceAddress(roadAddress: widget.post.warehouseName);
  late DateTime? _paymentDate = widget.post.paymentDate;
  late SalaryPaymentMonthOffset? _paymentMonthOffset =
      widget.post.paymentMonthOffset;
  late int? _paymentDayOfMonth = widget.post.paymentDayOfMonth;
  late JobPostNotificationSettings? _notificationSettings =
      widget.post.notificationSettings;
  late CorporateJobPostStatus _status = widget.post.status;
  late WorkerCategory _workerCategory = widget.post.effectiveWorkerCategory;
  late SalaryPayType _salaryPayType =
      parseSalaryPayType(widget.post.hourlyWage);
  bool _submitting = false;
  List<CorporateBranch> _branches = [];
  CorporateBranch? _selectedBranch;

  @override
  void initState() {
    super.initState();
    _loadBranches();
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
    _jobDescriptionController.dispose();
    _wageController.dispose();
    _scheduleController.dispose();
    _summaryController.dispose();
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

  Future<void> _pickPaymentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: '급여지급일 선택',
      cancelText: '취소',
      confirmText: '확인',
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
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('결제가 취소되어 수정을 완료하지 못했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    notificationSettings = paymentOutcome.notificationSettings;
    paymentRecord = paymentOutcome.paymentRecord ?? widget.post.paymentRecord;
    extraPushFeeKrw = paymentOutcome.extraPushFeeKrw;
    setState(() => _notificationSettings = notificationSettings);

    final wageLabel = _salaryPayType.formatAmount(_wageController.text);
    final result = await _updatePost(
      original: widget.post,
      title: _titleController.text,
      workplace: _workplace,
      hourlyWage: wageLabel,
      workSchedule: _scheduleController.text,
      jobDescription: _jobDescriptionController.text,
      summary: _summaryController.text,
      paymentSchedule: paymentSchedule,
      workerCategory: _workerCategory,
      status: _status,
      notificationSettings: notificationSettings,
      paymentRecord: paymentRecord,
      branchId: _selectedBranch?.id,
      branchName: _selectedBranch?.name,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '수정에 실패했습니다.')),
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
        title: const Text('일자리 수정'),
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
          submitLabel: '수정 저장',
          submitting: _submitting,
          onSubmit: _submit,
          beforeSubmit: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
        ),
      ),
    );
  }
}
