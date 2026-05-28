import 'package:flutter/foundation.dart';
import 'package:map/core/config/env_config.dart';

/// flutter_naver_map은 Android/iOS에서만 동작합니다.
abstract final class NaverMapPlatform {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get shouldShowMap =>
      isSupported && EnvConfig.isNaverMapConfigured;
}
