import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_age.dart';

/// 구직자 공개 프로필 (기업 근태·지원자·이력서 화면용)
class SeekerPublicProfile {
  const SeekerPublicProfile({
    required this.genderLabel,
    required this.ageLabel,
    required this.birthDateLabel,
    this.experienceSummary,
    this.preferredRegions = const [],
    this.preferredJobCategories = const [],
  });

  final String genderLabel;
  final String ageLabel;
  final String birthDateLabel;
  final String? experienceSummary;
  final List<String> preferredRegions;
  final List<String> preferredJobCategories;

  static const unknown = SeekerPublicProfile(
    genderLabel: '-',
    ageLabel: '-',
    birthDateLabel: '-',
  );
}

abstract final class SeekerProfileLookup {
  static SeekerPublicProfile forAuthUser(AuthUser user) {
    final profile = user.seekerProfile;
    if (profile != null) {
      return _fromMemberProfile(profile);
    }
    return forEmail(user.email);
  }

  static SeekerPublicProfile forEmail(String email) {
    final account = DevTestAccounts.seekerByEmail(email);
    final profile = account?.verifiedSeekerProfile;
    if (profile != null) {
      return _fromMemberProfile(profile);
    }
    return SeekerPublicProfile.unknown;
  }

  static SeekerMemberProfile? memberProfileForEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final current = AuthSession.instance.currentUser;
    if (current != null &&
        current.email.trim().toLowerCase() == normalized) {
      return current.seekerProfile;
    }
    return DevTestAccounts.seekerByEmail(email)?.verifiedSeekerProfile;
  }

  static SeekerPublicProfile _fromMemberProfile(SeekerMemberProfile profile) {
    return SeekerPublicProfile(
      genderLabel: profile.gender?.resumeLabel ?? '-',
      ageLabel: SeekerAge.formatLabel(profile.dateOfBirth),
      birthDateLabel: formatBirthDate(profile.dateOfBirth),
      experienceSummary: profile.experienceSummary,
      preferredRegions: profile.preferredRegions,
      preferredJobCategories: profile.preferredJobCategories,
    );
  }

  static String formatBirthDate(DateTime? dob) {
    if (dob == null) return '-';
    final y = dob.year.toString();
    final m = dob.month.toString().padLeft(2, '0');
    final d = dob.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}
