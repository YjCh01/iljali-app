import 'dart:html' as html;

import 'package:map/core/config/env_config.dart';

abstract final class NaverMapWebClientIdLoader {
  static String? _runtimeId;

  static String? get runtimeId => _runtimeId;

  static Future<void> load() async {
    if (_runtimeId != null && _runtimeId!.isNotEmpty) return;

    if (EnvConfig.isNaverMapConfigured) {
      _runtimeId = EnvConfig.naverMapClientId.trim();
      return;
    }

    try {
      final response = await html.HttpRequest.getString(
        '/naver_map_client_id.txt?v=${DateTime.now().millisecondsSinceEpoch}',
      );
      final line = response
          .replaceAll('\uFEFF', '')
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      if (_isValid(line)) {
        _runtimeId = line;
      }
    } on Object {
      // ignore — fall back to dart-define only
    }
  }

  static String resolve() {
    final runtime = _runtimeId?.trim();
    if (runtime != null && runtime.isNotEmpty) return runtime;
    if (EnvConfig.isNaverMapConfigured) {
      return EnvConfig.naverMapClientId.trim();
    }
    return '';
  }

  static bool _isValid(String value) {
    if (value.isEmpty) return false;
    const placeholders = {
      'YOUR_NAVER_MAP_CLIENT_ID',
      'PASTE_CLIENT_ID_HERE',
      '여기_한_줄만_지우고_NCP_인증정보의_Client_ID를_붙여넣으세요',
    };
    return !placeholders.contains(value);
  }
}
