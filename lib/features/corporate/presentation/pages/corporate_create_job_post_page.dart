import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/datasources/create_job_post_wizard_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/premium_company.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';
import 'package:map/features/corporate/data/repositories/partnership_notice_repository.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/wizard_widgets.dart';

enum _WizardStep {
  premiumQuestion,
  premiumBenefitsNotice,
  selectCompany,
  reusePreviousQuestion,
  previousPostsList,
  selectJobRole,
}

class _WizardLogEntry {
  const _WizardLogEntry.question(this.text) : answer = null;
  const _WizardLogEntry.answer(this.answer) : text = null;

  final String? text;
  final String? answer;
}

/// 기업회원 — 공고 등록 질문 플로우 (Speed Dial 1)
class CorporateCreateJobPostPage extends StatefulWidget {
  const CorporateCreateJobPostPage({super.key});

  @override
  State<CorporateCreateJobPostPage> createState() =>
      _CorporateCreateJobPostPageState();
}

class _CorporateCreateJobPostPageState extends State<CorporateCreateJobPostPage> {
  final _wizardData = const CreateJobPostWizardLocalDataSourceImpl();
  final _getPosts = const GetCorporateJobPostsUseCase(
    CorporateJobPostLocalDataSourceImpl(),
  );

  _WizardStep _step = _WizardStep.premiumQuestion;
  final List<_WizardLogEntry> _log = [];

  List<PremiumCompany> _companies = [];
  List<CorporateJobPost> _allPosts = [];
  List<CorporateJobPost> _companyPosts = [];
  List<JobRoleOption> _jobRoles = [];

  PremiumCompany? _selectedCompany;

  bool _loading = true;
  bool _showPlanChangeOptions = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _wizardData.fetchPremiumCompanies(),
      _getPosts(),
      _wizardData.fetchJobRoles(),
    ]);
    if (!mounted) return;
    setState(() {
      _companies = results[0] as List<PremiumCompany>;
      _allPosts = results[1] as List<CorporateJobPost>;
      _jobRoles = (results[2] as List<JobRoleOption>)
          .where((role) => ProductFeatureFlags.isJobRoleIdAllowed(role.id))
          .toList();
      _loading = false;
    });
  }

  void _appendQuestion(String text) {
    _log.add(_WizardLogEntry.question(text));
  }

  void _appendAnswer(String text) {
    _log.add(_WizardLogEntry.answer(text));
  }

  void _onPremiumAnswer(bool isPremium) {
    _appendQuestion(PremiumPartnershipPlans.questionText);
    _appendAnswer(isPremium ? '네' : '아니오');
    if (isPremium) {
      _appendQuestion('해당 기업을 선택해주세요');
      setState(() => _step = _WizardStep.selectCompany);
    } else {
      _sendPartnershipNotice();
      setState(() {
        _showPlanChangeOptions = false;
        _step = _WizardStep.premiumBenefitsNotice;
      });
    }
  }

  Future<void> _sendPartnershipNotice() async {
    final repo = await PartnershipNoticeRepository.create();
    await repo.sendPartnershipNotice();
  }

  void _onCompanySelected(PremiumCompany company) {
    _selectedCompany = company;
    _appendAnswer(company.name);
    _companyPosts = _allPosts
        .where((post) => post.warehouseName == company.name)
        .toList();
    _appendQuestion('이전에 채용하신 조건으로 채용하시겠습니까?');
    setState(() => _step = _WizardStep.reusePreviousQuestion);
  }

  void _onReusePreviousAnswer(bool reuse) {
    _appendAnswer(reuse ? '네' : '아니오');
    if (reuse) {
      _appendQuestion('이전 공고 목록');
      setState(() => _step = _WizardStep.previousPostsList);
    } else {
      _appendQuestion(CreateJobPostWizardLocalDataSourceImpl.workerTypeQuestion);
      setState(() => _step = _WizardStep.selectJobRole);
    }
  }

  void _onPreviousPostSelected(CorporateJobPost post) {
    _appendAnswer(post.title);
    _openWritePage(
      JobPostWriteDraft(
        title: post.title,
        workplaceAddress: post.warehouseName,
        hourlyWage: post.hourlyWage.replaceAll(RegExp(r'[^0-9]'), ''),
        workSchedule: post.workSchedule,
        jobDescription: post.jobDescription.isNotEmpty
            ? post.jobDescription
            : post.summary,
        summary: post.jobDescription.isNotEmpty ? post.summary : '',
        paymentDate: post.paymentDate,
        paymentMonthOffset: post.paymentMonthOffset,
        paymentDayOfMonth: post.paymentDayOfMonth,
        notificationSettings: post.notificationSettings,
        employmentType: post.employmentType,
        workerCategory: post.effectiveWorkerCategory,
      ),
    );
  }

  void _onJobRoleSelected(JobRoleOption role) {
    _appendAnswer(role.label);
    final workerCategory = workerCategoryFromRoleId(role.id) ??
        ProductFeatureFlags.defaultWorkerCategory;
    _openWritePage(
      JobPostWriteDraft(
        title: '${role.label} 모집',
        employmentType: workerCategory.employmentType,
        workerCategory: workerCategory,
      ),
    );
  }

  Future<void> _openWritePage(JobPostWriteDraft draft) async {
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateJobPostWrite,
      arguments: draft,
    );
    if (created == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openPushPackageShop() async {
    final purchased = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushPackageShop,
    );
    if (purchased == true && mounted) {
      setState(() => _showPlanChangeOptions = false);
    }
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
        title: const Text('공고 등록'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    children: [
                      ..._buildLog(),
                      const SizedBox(height: 12),
                      ..._buildCurrentStep(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildLog() {
    return _log.map((entry) {
      if (entry.text != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WizardQuestionBubble(text: entry.text!),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: WizardAnswerBubble(text: entry.answer!),
      );
    }).toList();
  }

  List<Widget> _buildCurrentStep() {
    return switch (_step) {
      _WizardStep.premiumQuestion => [
          WizardQuestionBubble(
            text: PremiumPartnershipPlans.questionText,
          ),
          const SizedBox(height: 16),
          WizardYesNoButtons(
            onYes: () => _onPremiumAnswer(true),
            onNo: () => _onPremiumAnswer(false),
          ),
        ],
      _WizardStep.premiumBenefitsNotice => [
          const WizardInfoBanner(
            message:
                '일자리 프로모션 제휴사 가입 시 혜택 사항을 채팅 탭으로 보내드렸습니다.',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            PartnershipPlanDefaults.activePlan.isPaid
                ? '현재 ${PartnershipPlanDefaults.activePlan.label} 플랜 · '
                    '유료 구독 활성'
                : '현재 ${PartnershipPlanDefaults.activePlan.label} 플랜 · '
                    '푸시·공고 등록만 가능',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: AppColors.textPrimary.withValues(alpha: 0.95),
            ),
          ),
          if (!_showPlanChangeOptions) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                PremiumPartnershipPlans.pushStrategyNote,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openWritePage(
                JobPostWriteDraft(
                  workerCategory: ProductFeatureFlags.defaultWorkerCategory,
                  employmentType:
                      ProductFeatureFlags.defaultWorkerCategory.employmentType,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '현재 플랜으로 공고 등록하기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _showPlanChangeOptions = !_showPlanChangeOptions),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '공고 노출·모집 패키지 보기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (_showPlanChangeOptions) ...[
            const SizedBox(height: 16),
            PartnershipTierCards(
              comparisonOnly: true,
              onShopTap: _openPushPackageShop,
            ),
          ],
        ],
      _WizardStep.selectCompany => [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: _companies.length,
            itemBuilder: (context, index) {
              final company = _companies[index];
              final selected = _selectedCompany?.id == company.id;
              return _CompanyIconTile(
                company: company,
                selected: selected,
                onTap: () => _onCompanySelected(company),
              );
            },
          ),
        ],
      _WizardStep.reusePreviousQuestion => [
          WizardYesNoButtons(
            onYes: () => _onReusePreviousAnswer(true),
            onNo: () => _onReusePreviousAnswer(false),
          ),
        ],
      _WizardStep.previousPostsList => [
          if (_companyPosts.isEmpty) ...[
            const WizardInfoBanner(
              message: '선택한 기업의 이전 공고가 없습니다. 새 조건으로 진행해 주세요.',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _onReusePreviousAnswer(false),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '새 조건으로 공고 등록하기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else
            ..._companyPosts.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CorporateJobPostCard(
                  post: post,
                  onTap: () => _onPreviousPostSelected(post),
                ),
              ),
            ),
        ],
      _WizardStep.selectJobRole => [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _jobRoles.map((role) {
              return _JobRoleChip(
                role: role,
                selected: false,
                onTap: () => _onJobRoleSelected(role),
              );
            }).toList(),
          ),
        ],
    };
  }
}

class _CompanyIconTile extends StatelessWidget {
  const _CompanyIconTile({
    required this.company,
    required this.selected,
    required this.onTap,
  });

  final PremiumCompany company;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.searchBarBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (company.hasBrandLogo)
                _PartnerBrandLogo(company: company)
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(company.icon, color: AppColors.primary),
                ),
              const SizedBox(height: 10),
              Text(
                company.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerBrandLogo extends StatelessWidget {
  const _PartnerBrandLogo({required this.company});

  final PremiumCompany company;

  @override
  Widget build(BuildContext context) {
    final bg = company.brandColor!;
    final fg = company.brandAccentColor ?? Colors.white;
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            company.logoMark!,
            style: TextStyle(
              fontSize: company.id == 'partner_coupang_fs' ? 14 : 20,
              fontWeight: FontWeight.w900,
              letterSpacing: company.id == 'partner_daiso' ? 1.2 : 0.5,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _JobRoleChip extends StatelessWidget {
  const _JobRoleChip({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final JobRoleOption role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryLight.withValues(alpha: 0.3)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.searchBarBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(role.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                role.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
