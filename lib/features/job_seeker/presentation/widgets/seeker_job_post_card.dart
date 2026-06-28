import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/trust/presentation/employer_trust_section.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';

/// 구직자 공고 목록 — 고용주 신뢰 배지 포함
class SeekerJobPostCard extends StatelessWidget {
  const SeekerJobPostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  final CorporateJobPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: CorporateJobPostCard(post: post),
          ),
        ),
        if (ProductFeatureFlags.isEmployerTrustDisplayEnabled) ...[
          if (post.registeredBy != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: EmployerTrustSection(
                companyKey: post.registeredBy!.companyKey,
                profile: post.registeredBy,
                compact: true,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Text(
                '사업자 미등록 공고 · 신뢰 정보 없음',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
