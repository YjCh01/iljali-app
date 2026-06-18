import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 구직자 공개 프로필 (기업 근태·지원자 화면용 — MVP: 테스트 계정 + 미등록 시 기본값)
class SeekerPublicProfile {
  const SeekerPublicProfile({
    required this.genderLabel,
    required this.birthDateLabel,
    this.experienceSummary,
    this.preferredJobCategories = const [],
  });

  final String genderLabel;
  final String birthDateLabel;
  final String? experienceSummary;
  final List<String> preferredJobCategories;

  static const unknown = SeekerPublicProfile(
    genderLabel: '-',
    birthDateLabel: '-',
  );
}

abstract final class SeekerProfileLookup {
  static SeekerPublicProfile forEmail(String email) {
    final account = DevTestAccounts.seekerByEmail(email);
    final profile = account?.verifiedSeekerProfile;
    if (profile != null) {
      return SeekerPublicProfile(
        genderLabel: profile.gender?.label ?? '-',
        birthDateLabel: _formatBirthDate(profile.dateOfBirth),
        experienceSummary: profile.experienceSummary,
        preferredJobCategories: profile.preferredJobCategories,
      );
    }
    return SeekerPublicProfile.unknown;
  }

  static String _formatBirthDate(DateTime? dob) {
    if (dob == null) return '-';
    final y = dob.year.toString();
    final m = dob.month.toString().padLeft(2, '0');
    final d = dob.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}
