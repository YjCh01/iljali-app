import 'package:map/core/config/env_config.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase Web — `--dart-define` 로 주입 (FlutterFire 미사용 환경)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: EnvConfig.firebaseApiKey,
      appId: EnvConfig.firebaseAppId,
      messagingSenderId: EnvConfig.firebaseMessagingSenderId,
      projectId: EnvConfig.firebaseProjectId,
    );
  }
}
