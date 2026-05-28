import 'package:shared_preferences/shared_preferences.dart';

/// 기업회원 가입 직후 3단계 웰컴 온보딩 — 1회만 표시
class CorporateOnboardingService {
  static const _keyPrefix = 'corp_welcome_onboarding_done_';

  Future<bool> shouldShow(String companyKey) async {
    if (companyKey.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_keyPrefix$companyKey') ?? false);
  }

  Future<void> markComplete(String companyKey) async {
    if (companyKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$companyKey', true);
  }
}
