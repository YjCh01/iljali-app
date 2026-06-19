import 'package:flutter/foundation.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NaverMapPlatform web branch requires client id on web', () {
    if (!kIsWeb) {
      expect(NaverMapPlatform.shouldUseWebMap, isFalse);
      return;
    }
    expect(NaverMapPlatform.shouldUseWebMap, EnvConfig.isNaverMapConfigured);
  });

  test('mock map only when no native or web map', () {
    if (kIsWeb) {
      expect(
        NaverMapPlatform.shouldUseMockMap,
        !EnvConfig.isNaverMapConfigured,
      );
    }
  });
}
