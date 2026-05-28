import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/trust/employer_trust_badge.dart';
import 'package:map/core/trust/local_company_rating_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 고용주 신뢰도·배지 — 구직자 지원 전 판단용
class EmployerTrustService {
  EmployerTrustService({
    LocalCompanyRatingRepository? ratingRepository,
    LocalHiringRepository? hiringRepository,
  })  : _ratingRepository = ratingRepository,
        _hiringRepository = hiringRepository;

  LocalCompanyRatingRepository? _ratingRepository;
  LocalHiringRepository? _hiringRepository;

  Future<LocalCompanyRatingRepository> _ratings() async =>
      _ratingRepository ??= await LocalCompanyRatingRepository.create();

  Future<LocalHiringRepository> _hiring() async =>
      _hiringRepository ??= await LocalHiringRepository.create();

  Future<EmployerTrustSummary> summarize({
    required String? companyKey,
    CorporateMemberProfile? profile,
  }) async {
    final key = companyKey ?? profile?.companyKey;
    if (key == null || key.isEmpty) {
      return const EmployerTrustSummary.empty();
    }

    final ratingSummary = await (await _ratings()).summarizeCompany(key);
    final apps = (await (await _hiring()).fetchAll())
        .where((a) => a.companyKey == key)
        .toList();

    var checkIns = 0;
    var completed = 0;
    for (final app in apps) {
      if (app.status == HiringApplicationStatus.checkedIn ||
          app.status == HiringApplicationStatus.commissionPaid) {
        checkIns++;
      }
      if (app.status == HiringApplicationStatus.commissionPaid) {
        completed++;
      }
    }

    final badges = <EmployerTrustBadge>[];
    if (profile != null) {
      if (profile.verificationStatus == BusinessVerificationStatus.verified) {
        badges.add(EmployerTrustBadge.verifiedBusiness);
      }
      if (profile.hasLegacyPaidSubscription ||
          (profile.pushWallet?.packageCredits ?? 0) > 0) {
        badges.add(EmployerTrustBadge.premiumPartner);
      }
      if (profile.isEnterpriseOutsourcing) {
        badges.add(EmployerTrustBadge.enterprise);
      }
    }
    if (ratingSummary.reviewCount >= 3 && ratingSummary.averageStars >= 4.5) {
      badges.add(EmployerTrustBadge.topRated);
    }
    if (checkIns >= 3 && completed >= 2) {
      badges.add(EmployerTrustBadge.reliableEmployer);
    }

    var score = 40;
    if (ratingSummary.reviewCount > 0) {
      score += (ratingSummary.averageStars * 12).round();
    }
    score += completed * 3;
    score += badges.length * 5;
    if (profile?.hasLegacyPaidSubscription == true ||
        (profile?.pushWallet?.packageCredits ?? 0) > 0) {
      score += 10;
    }
    score = score.clamp(0, 100);

    return EmployerTrustSummary(
      score: score,
      badges: badges,
      ratingSummary: ratingSummary,
      completedHires: completed,
    );
  }
}
