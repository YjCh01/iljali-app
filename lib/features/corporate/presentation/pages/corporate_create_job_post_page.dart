import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/wizard_widgets.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 기업회원 — 공고 등록 안내 후 작성 화면으로 이동
class CorporateCreateJobPostPage extends StatelessWidget {
  const CorporateCreateJobPostPage({super.key});

  Future<void> _openImportPage(BuildContext context) async {
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateJobPostImport,
    );
    if (created == true && context.mounted) {
      Navigator.of(context).pop(
        const CorporateJobPostFlowResult(shellTabIndex: 1),
      );
    }
  }

  Future<void> _openWritePage(BuildContext context, JobPostWriteDraft draft) async {
    final flowResult =
        await Navigator.of(context).pushNamed<CorporateJobPostFlowResult>(
      AppRoutes.corporateJobPostWrite,
      arguments: draft,
    );
    if (flowResult != null && context.mounted) {
      Navigator.of(context).pop(flowResult);
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
                '공고 등록은 무료입니다.\n'
                '등록한 공고는 근무지 주변 ${PushPackageCatalog.pushRadiusLabel}에 지도 핀으로 무료 노출됩니다.\n\n'
                '다른 지역·셔틀 정류장 노출은 등록 후 일자리 알림핀으로 추가할 수 있습니다.',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openImportPage(context),
              icon: const Icon(Icons.auto_awesome_outlined),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                JobPostImportCopy.ctaLabel,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openWritePage(
                context,
                JobPostWriteDraft(
                  workerCategory: ProductFeatureFlags.defaultWorkerCategory,
                  employmentType:
                      ProductFeatureFlags.defaultWorkerCategory.employmentType,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '직접 입력으로 등록',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
