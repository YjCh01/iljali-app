import 'package:map/features/auth/domain/utils/resident_id_front.dart';
import 'package:map/features/auth/domain/validators/name_validator.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 개인회원 2단계 — 지원·매칭용 프로필 완성 여부
abstract final class SeekerProfileReadiness {
  /// 1단계 가입 완료 (휴대폰 본인인증 + 계정)
  static bool hasBasicAccount(SeekerMemberProfile? profile) =>
      profile != null && profile.phoneVerified;

  /// 2단계 — 이름·실주소·근무지역·스케줄 등 매칭 필수값
  static bool isProfileFieldsReady(
    SeekerMemberProfile? profile, {
    String? displayName,
  }) {
    if (profile == null || !profile.phoneVerified) return false;
    if (!NameValidator.validate(displayName).isValid) return false;

    final rrnText = profile.residentIdFront7?.trim() ?? '';
    if (rrnText.isEmpty) return false;
    if (ResidentIdFront.tryParse(rrnText) == null) return false;

    if (!profile.hasHomeAddress) return false;
    if (profile.preferredRegions.isEmpty) return false;
    if (profile.workAvailability.isEmpty) return false;
    return true;
  }

  /// 지원·매칭 가능 — 완료 플래그 또는 필수 필드 충족
  static bool isMatchingReady(
    SeekerMemberProfile? profile, {
    String? displayName,
  }) {
    if (profile == null || !profile.phoneVerified) return false;
    if (profile.isOnboardingComplete) return true;
    return isProfileFieldsReady(profile, displayName: displayName);
  }

  /// 프로필 완성 안내에 쓸 미입력 항목
  static List<String> missingMatchingFields(
    SeekerMemberProfile? profile, {
    String? displayName,
  }) {
    if (profile == null || !profile.phoneVerified) {
      return const ['로그인·본인인증'];
    }
    final missing = <String>[];
    if (!NameValidator.validate(displayName).isValid) {
      missing.add('이름');
    }
    final rrnText = profile.residentIdFront7?.trim() ?? '';
    if (rrnText.isEmpty || ResidentIdFront.tryParse(rrnText) == null) {
      missing.add('주민번호 앞자리');
    }
    if (!profile.hasHomeAddress) missing.add('실주소');
    if (profile.preferredRegions.isEmpty) missing.add('희망 근무지역');
    if (profile.workAvailability.isEmpty) missing.add('근무 스케줄');
    return missing;
  }

  static const applyBlockedMessage =
      '지원·채용 매칭을 위해 프로필(이름·실주소·근무지역·스케줄)을 완성해 주세요.';

  static const browseHintMessage =
      '가입이 완료되었습니다. 지도에서 공고를 둘러보세요. 지원하려면 더보기에서 프로필을 완성해 주세요.';
}
