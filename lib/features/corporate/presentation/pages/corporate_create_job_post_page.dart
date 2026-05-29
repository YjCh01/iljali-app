import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/wizard_widgets.dart';

/// 기업회원 — 공고 등록 안내 후 작성 화면으로 이동
class CorporateCreateJobPostPage extends StatefulWidget {
  const CorporateCreateJobPostPage({super.key});

  @override
  State<CorporateCreateJobPostPage> createState() =>
      _CorporateCreateJobPostPageState();
}

class _CorporateCreateJobPostPageState extends State<CorporateCreateJobPostPage> {
  bool _showPlanChangeOptions = false;

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        children: [
          const WizardInfoBanner(
            message:
                '공고 등록은 완전 무료입니다. 등록 후 근무지 1km 무료 푸시(일 1회)를 사용할 수 있습니다. '
                '추가 모집지역은 지역 푸시권으로 설정하거나 모집하기 발송 시 사용됩니다.',
            icon: Icons.notifications_active_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            '현재 ${PushPackageCatalog.defaultPlanLabel} · '
            '공고 등록 무료 · 근무지 1km 무료 푸시(일 1회)',
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
                '공고 등록하기',
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
                '지역 푸시권 보기',
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
      ),
    );
  }
}
