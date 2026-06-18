import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_preview_panel.dart';

/// 기업회원 — 공고 미리보기 (지원자 노출 화면 확인)
Future<void> showCorporateJobPostPreviewSheet(
  BuildContext context,
  CorporateJobPost post,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CorporateJobPostPreviewSheet(post: post),
  );
}

class CorporateJobPostPreviewSheet extends StatelessWidget {
  const CorporateJobPostPreviewSheet({super.key, required this.post});

  final CorporateJobPost post;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomInset),
            child: CorporateJobPostPreviewPanel(
              post: post,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}
