import 'package:flutter/services.dart';

/// 모바일·데스크톱: 링크를 클립보드에 복사 (브라우저는 [external_link_launcher_web] 사용)
Future<bool> openExternalUrl(String url) async {
  if (url.trim().isEmpty) return false;
  await Clipboard.setData(ClipboardData(text: url));
  return false;
}
