import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_readiness.dart';

/// 로그인·동기화 시 로컬·서버 프로필 병합
abstract final class SeekerProfileMerge {
  static int richnessScore(SeekerMemberProfile profile, {String? displayName}) {
    var score = 0;
    if (profile.isOnboardingComplete) score += 200;
    if (SeekerProfileReadiness.isProfileFieldsReady(
      profile,
      displayName: displayName,
    )) {
      score += 100;
    }
    if (profile.hasHomeAddress) score += 20;
    if (profile.residentIdFront7?.trim().isNotEmpty ?? false) score += 15;
    if (profile.preferredRegions.isNotEmpty) score += 10;
    if (!profile.workAvailability.isEmpty) score += 10;
    if (profile.credentialHoldings.isNotEmpty) score += 8;
    if (profile.resume.educations.isNotEmpty) score += 5;
    if (profile.resume.experiences.isNotEmpty) score += 5;
    if (profile.experienceSummary?.trim().isNotEmpty ?? false) score += 3;
    if (profile.phoneVerified) score += 1;
    return score;
  }

  /// 여러 출처 중 더 채워진 프로필을 기준으로 빈 칸만 합침
  static SeekerMemberProfile mergePreferRicher(
    Iterable<SeekerMemberProfile?> sources, {
    String? displayName,
  }) {
    final list = sources.whereType<SeekerMemberProfile>().toList();
    if (list.isEmpty) {
      return const SeekerMemberProfile(phoneVerified: true);
    }

    list.sort(
      (a, b) => richnessScore(b, displayName: displayName)
          .compareTo(richnessScore(a, displayName: displayName)),
    );

    var merged = list.first;
    for (final other in list.skip(1)) {
      merged = _fillGaps(merged, other);
    }
    return merged;
  }

  static SeekerMemberProfile _fillGaps(
    SeekerMemberProfile primary,
    SeekerMemberProfile secondary,
  ) {
    final resume = _mergeResume(primary.resume, secondary.resume);
    return primary.copyWith(
      phoneVerified: primary.phoneVerified || secondary.phoneVerified,
      dateOfBirth: primary.dateOfBirth ?? secondary.dateOfBirth,
      gender: primary.gender ?? secondary.gender,
      residentIdFront7: _nonEmpty(primary.residentIdFront7, secondary.residentIdFront7),
      nationality: primary.nationality ?? secondary.nationality,
      preferredRegions: primary.preferredRegions.isNotEmpty
          ? primary.preferredRegions
          : secondary.preferredRegions,
      preferredJobCategories: primary.preferredJobCategories.isNotEmpty
          ? primary.preferredJobCategories
          : secondary.preferredJobCategories,
      workAvailability: primary.workAvailability.isEmpty
          ? secondary.workAvailability
          : primary.workAvailability,
      profilePhotoRef:
          _nonEmpty(primary.profilePhotoRef, secondary.profilePhotoRef),
      experienceSummary:
          _nonEmpty(primary.experienceSummary, secondary.experienceSummary),
      resume: resume,
      credentialHoldings: _mergeCredentialHoldings(
        primary.credentialHoldings,
        secondary.credentialHoldings,
      ),
      termsAcceptedAt: primary.termsAcceptedAt ?? secondary.termsAcceptedAt,
      termsVersionAccepted: _nonEmpty(
        primary.termsVersionAccepted,
        secondary.termsVersionAccepted,
      ),
      privacyVersionAccepted: _nonEmpty(
        primary.privacyVersionAccepted,
        secondary.privacyVersionAccepted,
      ),
      onboardingCompletedAt:
          primary.onboardingCompletedAt ?? secondary.onboardingCompletedAt,
      homeRoadAddress:
          _nonEmpty(primary.homeRoadAddress, secondary.homeRoadAddress),
      homeDetailAddress:
          _nonEmpty(primary.homeDetailAddress, secondary.homeDetailAddress),
      homeLatitude: primary.homeLatitude ?? secondary.homeLatitude,
      homeLongitude: primary.homeLongitude ?? secondary.homeLongitude,
      locationConsentAcceptedAt: primary.locationConsentAcceptedAt ??
          secondary.locationConsentAcceptedAt,
      locationConsentVersion: _nonEmpty(
        primary.locationConsentVersion,
        secondary.locationConsentVersion,
      ),
      proposalOffersAccepted:
          primary.proposalOffersAccepted || secondary.proposalOffersAccepted,
    );
  }

  static SeekerResumeContent _mergeResume(
    SeekerResumeContent primary,
    SeekerResumeContent secondary,
  ) {
    return SeekerResumeContent(
      educations:
          primary.educations.isNotEmpty ? primary.educations : secondary.educations,
      experiences: primary.experiences.isNotEmpty
          ? primary.experiences
          : secondary.experiences,
      licenses: primary.licenses.isNotEmpty ? primary.licenses : secondary.licenses,
      certifications: primary.certifications.isNotEmpty
          ? primary.certifications
          : secondary.certifications,
      selfIntroduction: primary.selfIntroduction.trim().isNotEmpty
          ? primary.selfIntroduction
          : secondary.selfIntroduction,
    );
  }

  static String? _nonEmpty(String? a, String? b) {
    final left = a?.trim() ?? '';
    if (left.isNotEmpty) return left;
    final right = b?.trim() ?? '';
    return right.isNotEmpty ? right : null;
  }

  static List<SeekerCredentialHolding> _mergeCredentialHoldings(
    List<SeekerCredentialHolding> primary,
    List<SeekerCredentialHolding> secondary,
  ) {
    final byId = <String, SeekerCredentialHolding>{};
    for (final holding in [...primary, ...secondary]) {
      if (holding.credentialId.isEmpty) continue;
      final existing = byId[holding.credentialId];
      if (existing == null) {
        byId[holding.credentialId] = holding;
        continue;
      }
      if (!existing.isComplete && holding.isComplete) {
        byId[holding.credentialId] = holding;
      }
    }
    return byId.values.toList();
  }
}
