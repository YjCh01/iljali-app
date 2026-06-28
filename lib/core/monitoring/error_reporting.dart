import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:map/core/config/env_config.dart';

/// Sentry DSN 설정 시 크래시 리포팅 — 미설정 시 Flutter 기본 핸들러
Future<void> initializeErrorReporting(void Function() runApp) async {
  final dsn = EnvConfig.sentryDsn;
  if (dsn.isEmpty) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('Uncaught: $error\n$stack');
      }
      return true;
    };
    runApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.sendDefaultPii = false;
    },
    appRunner: runApp,
  );
}
