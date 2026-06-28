/// 프로필 온보딩 진입 목적
class SeekerProfileOnboardingArgs {
  const SeekerProfileOnboardingArgs({this.forJobApply = false});

  /// 공고 「지원하기」에서 넘어온 경우 — 필수 항목만 입력 후 지원 흐름으로 복귀
  final bool forJobApply;

  static const forApply = SeekerProfileOnboardingArgs(forJobApply: true);

  static SeekerProfileOnboardingArgs from(Object? raw) {
    if (raw is SeekerProfileOnboardingArgs) return raw;
    if (raw == true || raw == 'apply') {
      return SeekerProfileOnboardingArgs.forApply;
    }
    return const SeekerProfileOnboardingArgs();
  }
}
