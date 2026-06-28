import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/trust/employer_trust_service.dart';
import 'package:map/core/trust/presentation/employer_trust_badge_row.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 공고·지도 상세 등 — companyKey 기준 고용주 신뢰 로드
class EmployerTrustSection extends StatelessWidget {
  const EmployerTrustSection({
    super.key,
    required this.companyKey,
    this.profile,
    this.compact = false,
  });

  final String? companyKey;
  final CorporateMemberProfile? profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!ProductFeatureFlags.isEmployerTrustDisplayEnabled) {
      return const SizedBox.shrink();
    }
    final key = companyKey ?? profile?.companyKey;
    if (key == null || key.isEmpty) return const SizedBox.shrink();

    return FutureBuilder(
      future: EmployerTrustService().summarize(
        companyKey: key,
        profile: profile,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.hasData) {
          return const SizedBox.shrink();
        }
        return EmployerTrustBadgeRow(
          summary: snapshot.data!,
          compact: compact,
        );
      },
    );
  }
}
