import 'package:flutter/foundation.dart';

/// Daum 우편번호 WebView — Android/iOS에서만 동작 (네이버 지도와 동일한 제약)
abstract final class WorkplaceAddressPlatform {
  static bool get isPostcodeWebViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
