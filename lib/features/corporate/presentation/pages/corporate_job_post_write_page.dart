import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_write_form_host.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 일자리 등록 — 최종 작성·저장
class CorporateJobPostWritePage extends StatelessWidget {
  const CorporateJobPostWritePage({
    super.key,
    this.draft = const JobPostWriteDraft(),
  });

  final JobPostWriteDraft draft;

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
          if (draft.importSourceLabel == null)
            TextButton(
              onPressed: () => _openImportPage(context),
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
        child: CorporateJobPostWriteFormHost(initialDraft: draft),
      ),
    );
  }
}
