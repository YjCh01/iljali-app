import 'package:map/core/session/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기업회원이 지원자 목록을 마지막으로 연 시각 — 그 이후 지원건에 "NEW" 표시용.
abstract final class CorporateApplicantsViewMarkerService {
  static const _key = 'corporate_applicants_last_viewed_v1';

  static String? get _companyKey =>
      AuthSession.instance.currentUser?.corporateProfile?.companyKey;

  static Future<DateTime?> lastViewedAt() async {
    final companyKey = _companyKey;
    if (companyKey == null || companyKey.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_key:$companyKey');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> markViewedNow() async {
    final companyKey = _companyKey;
    if (companyKey == null || companyKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_key:$companyKey',
      DateTime.now().toIso8601String(),
    );
  }
}
