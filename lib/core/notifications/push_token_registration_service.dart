import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FCM 토큰·알림 설정 — 서버 등록
abstract final class PushTokenRegistrationService {
  static String? _currentToken;

  static String? get currentToken => _currentToken;

  static Future<void> registerToken(String token) async {
    if (!EnvConfig.isComplianceApiEnabled || token.trim().isEmpty) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    if (AuthSession.instance.accessToken == null) return;

    final prefs = await PushNotificationPreferences.load();
    await client.registerPushDevice(
      fcmToken: token,
      chatEnabled: prefs.chatEnabled,
      jobAlertsEnabled: prefs.jobAlertsEnabled,
      applicationUpdatesEnabled: prefs.applicationUpdatesEnabled,
    );
    _currentToken = token;
  }

  static Future<void> syncPreferences(PushNotificationPreferences prefs) async {
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    if (!EnvConfig.isComplianceApiEnabled) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    if (AuthSession.instance.accessToken == null) return;
    await client.updatePushDevicePreferences(
      fcmToken: token,
      chatEnabled: prefs.chatEnabled,
      jobAlertsEnabled: prefs.jobAlertsEnabled,
      applicationUpdatesEnabled: prefs.applicationUpdatesEnabled,
    );
  }

  static Future<void> unregisterCurrent() async {
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    if (!EnvConfig.isComplianceApiEnabled) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    try {
      await client.unregisterPushDevice(token);
    } on Object {
      // ignore
    }
    _currentToken = null;
  }
}

class PushNotificationPreferences {
  const PushNotificationPreferences({
    required this.chatEnabled,
    required this.jobAlertsEnabled,
    required this.applicationUpdatesEnabled,
  });

  final bool chatEnabled;
  final bool jobAlertsEnabled;
  final bool applicationUpdatesEnabled;

  static const _prefix = 'push_pref_v1_';

  static Future<PushNotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PushNotificationPreferences(
      chatEnabled:
          prefs.getBool('${_prefix}chat') ?? prefs.getBool('seeker_notif_chat') ?? true,
      jobAlertsEnabled: prefs.getBool('${_prefix}job_alerts') ??
          prefs.getBool('seeker_notif_job_alerts') ??
          true,
      applicationUpdatesEnabled: prefs.getBool('${_prefix}application') ??
          prefs.getBool('seeker_notif_application') ??
          true,
    );
  }

  static Future<void> save(PushNotificationPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}chat', value.chatEnabled);
    await prefs.setBool('${_prefix}job_alerts', value.jobAlertsEnabled);
    await prefs.setBool(
      '${_prefix}application',
      value.applicationUpdatesEnabled,
    );
  }
}
