import 'package:flutter/foundation.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/dev/dev_test_data_seeder.dart';
import 'package:map/core/session/auth_session.dart';

/// debug 빌드 전용 — 검증 우회 테스트 계정 로그인
abstract final class DevAuthService {
  static bool get isEnabled => kDebugMode;

  static Future<void> signIn(DevTestAccount account) async {
    if (!isEnabled) {
      throw StateError('DevAuthService is debug-only');
    }
    await DevTestDataSeeder.ensureSeeded();
    await AuthSession.instance.signIn(account.toAuthUser());
  }
}
