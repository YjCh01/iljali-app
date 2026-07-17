import 'package:shared_preferences/shared_preferences.dart';

/// 미인증(사업자등록증 미제출) 기업회원의 "무료 공고 1회" 사용 여부 — 기기 로컬 저장.
/// 인증 전에는 공고 1개를 1회만, 24시간만 등록 가능하고 그 이후엔 인증해야
/// 다시 공고를 등록할 수 있다 (검증 완료 후에는 이 제한이 사라짐).
abstract final class UnverifiedEmployerTrialPostPolicy {
  static const _key = 'unverified_employer_trial_post_used_v1';
  static const trialDuration = Duration(hours: 24);

  static Future<bool> hasUsedTrialPost(String companyKey) async {
    if (companyKey.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_key) ?? const [];
    return used.contains(companyKey);
  }

  static Future<void> markTrialPostUsed(String companyKey) async {
    if (companyKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_key) ?? const [];
    if (used.contains(companyKey)) return;
    await prefs.setStringList(_key, [...used, companyKey]);
  }

  static DateTime trialExpiresAt(DateTime postedAt) =>
      postedAt.add(trialDuration);
}
