import 'package:shared_preferences/shared_preferences.dart';

/// 앱 온보딩·코치마크 표시 여부 (SharedPreferences)
abstract final class UserOnboardingFlags {
  static const mapTutorialSeen = 'onboarding_map_tutorial_seen';
  static const mapAreaSearchCoachDismissed =
      'onboarding_map_area_search_coach_dismissed';
  static const vaultCompareHintSeen = 'onboarding_vault_compare_hint_seen';
  static const corporateWelcomeSeen = 'onboarding_corporate_welcome_seen';

  static Future<bool> getBool(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<bool> isMapAreaSearchCoachDismissed() =>
      getBool(mapAreaSearchCoachDismissed);

  static Future<void> dismissMapAreaSearchCoach() =>
      setBool(mapAreaSearchCoachDismissed, true);
}
