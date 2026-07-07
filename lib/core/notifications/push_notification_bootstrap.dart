import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/config/firebase_options.dart';
import 'package:map/core/notifications/push_incoming_handler.dart';
import 'package:map/core/notifications/push_token_registration_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase Messaging 초기화 — 로그인 후 토큰 등록
abstract final class PushNotificationBootstrap {
  static bool _initialized = false;

  static Future<void> initializeApp() async {
    if (_initialized || !EnvConfig.isFirebaseConfigured) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _initialized = true;
  }

  static Future<void> bindToSession() async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await initializeApp();

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await messaging.getToken(
      vapidKey: EnvConfig.firebaseVapidKey,
    );
    if (token != null && AuthSession.instance.isLoggedIn) {
      await PushTokenRegistrationService.registerToken(token);
    }

    messaging.onTokenRefresh.listen((next) async {
      if (AuthSession.instance.isLoggedIn) {
        await PushTokenRegistrationService.registerToken(next);
      }
    });

    FirebaseMessaging.onMessage.listen(PushIncomingHandler.handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(
      PushIncomingHandler.handleOpenedApp,
    );

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      await PushIncomingHandler.handleOpenedApp(initial);
    }
  }

  static Future<void> clearOnSignOut() async {
    await PushTokenRegistrationService.unregisterCurrent();
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!EnvConfig.isFirebaseConfigured) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushIncomingHandler.handleBackground(message);
}
