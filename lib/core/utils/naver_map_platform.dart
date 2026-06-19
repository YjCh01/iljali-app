import 'package:flutter/foundation.dart';
import 'package:map/core/config/env_config.dart';

/// flutter_naver_map(Android/iOS) + NAVER Maps JS(웹) 플랫폼 분기
abstract final class NaverMapPlatform {
  static bool get isNativeSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isWebSupported =>
      kIsWeb && EnvConfig.isNaverMapConfigured;

  /// 네이티브 SDK 또는 웹 JS 지도 사용 (mock 아님)
  static bool get shouldShowMap =>
      (isNativeSupported && EnvConfig.isNaverMapConfigured) || isWebSupported;

  static bool get shouldUseWebMap => isWebSupported;

  static bool get shouldUseNativeMap =>
      isNativeSupported && EnvConfig.isNaverMapConfigured;

  static bool get shouldUseMockMap => !shouldShowMap;

  /// @Deprecated — [shouldUseNativeMap] 사용
  static bool get isSupported => isNativeSupported;
}
