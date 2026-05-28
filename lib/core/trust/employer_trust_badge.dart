import 'package:map/core/trust/company_rating.dart';

/// 고용주 신뢰 배지 — 구직자 앱 표시용
enum EmployerTrustBadge {
  verifiedBusiness,
  premiumPartner,
  topRated,
  reliableEmployer,
  enterprise,
}

extension EmployerTrustBadgeX on EmployerTrustBadge {
  String get label => switch (this) {
        EmployerTrustBadge.verifiedBusiness => '사업자 인증',
        EmployerTrustBadge.premiumPartner => '유료 파트너',
        EmployerTrustBadge.topRated => '우수 고용주',
        EmployerTrustBadge.reliableEmployer => '정산 신뢰',
        EmployerTrustBadge.enterprise => 'Enterprise',
      };

  String get emoji => switch (this) {
        EmployerTrustBadge.verifiedBusiness => '🛡️',
        EmployerTrustBadge.premiumPartner => '💎',
        EmployerTrustBadge.topRated => '⭐',
        EmployerTrustBadge.reliableEmployer => '✅',
        EmployerTrustBadge.enterprise => '🏢',
      };
}

class EmployerTrustSummary {
  const EmployerTrustSummary({
    required this.score,
    required this.badges,
    required this.ratingSummary,
    required this.completedHires,
  });

  const EmployerTrustSummary.empty()
      : score = 0,
        badges = const [],
        ratingSummary = const CompanyRatingSummary(
          averageStars: 0,
          reviewCount: 0,
          topTags: [],
        ),
        completedHires = 0;

  final int score;
  final List<EmployerTrustBadge> badges;
  final CompanyRatingSummary ratingSummary;
  final int completedHires;

  bool get hasData =>
      ratingSummary.reviewCount > 0 || badges.isNotEmpty || completedHires > 0;
}
