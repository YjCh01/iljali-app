import 'package:map/core/session/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자가 "내일자리" 탭을 마지막으로 연 시각 — 그 이후 근무·면접 확정 건에
/// 배지 표시용.
abstract final class SeekerMyJobsViewMarkerService {
  static const _key = 'seeker_my_jobs_last_viewed_v1';

  static String? get _email => AuthSession.instance.currentUser?.email;

  static Future<DateTime?> lastViewedAt() async {
    final email = _email;
    if (email == null || email.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_key:$email');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> markViewedNow() async {
    final email = _email;
    if (email == null || email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_key:$email',
      DateTime.now().toIso8601String(),
    );
  }
}
