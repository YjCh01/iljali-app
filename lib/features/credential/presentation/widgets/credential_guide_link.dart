import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';

/// 자격·동의 항목 — 약관 전문 보기
class CredentialGuideLink extends StatelessWidget {
  const CredentialGuideLink({
    super.key,
    required this.definition,
    this.dense = false,
  });

  final CredentialDefinition definition;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final docId = definition.guideDocumentId;
    if (docId == null || docId.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: dense
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          minimumSize: dense ? Size.zero : null,
          tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
          visualDensity: dense ? VisualDensity.compact : null,
        ),
        onPressed: () {
          Navigator.of(context).pushNamed(
            AppRoutes.legalDocuments,
            arguments: {'initialDocumentId': docId},
          );
        },
        child: Text(
          '전문보기',
          style: TextStyle(
            fontSize: dense ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
