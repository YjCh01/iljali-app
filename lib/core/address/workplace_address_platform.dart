import 'package:flutter/foundation.dart';

/// Daum 우편번호 — Android/iOS WebView · 웹 DOM embed
abstract final class WorkplaceAddressPlatform {
  /// Daum postcode picker (mobile WebView or web Kakao Postcode JS).
  static bool get isPostcodeSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Native WebView only — excludes web DOM embed.
  static bool get isPostcodeWebViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Windows/macOS/Linux desktop — QC manual input fallback.
  static bool get isQcManualPrimaryMode => !isPostcodeSupported;
}
