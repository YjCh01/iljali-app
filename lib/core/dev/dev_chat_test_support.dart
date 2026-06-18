import 'package:flutter/foundation.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/dev/dev_test_data_seeder.dart';
import 'package:map/core/session/auth_session.dart';

/// debug — 구인자 채팅 탭·대화 테스트 준비
abstract final class DevChatTestSupport {
  static bool get isEnabled => kDebugMode;

  static DevTestAccount? currentDevCorporate() {
    if (!isEnabled) return null;
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return null;
    return DevTestAccounts.corporateByEmail(email);
  }

  /// 테스트 지원자 시드 + 검증 프로필 동기화
  static Future<bool> ensureCorporateChatReady() async {
    final dev = currentDevCorporate();
    if (dev == null) return false;

    await DevTestDataSeeder.ensureSeeded();

    final verified = dev.verifiedCorporateProfile!;
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null ||
        profile.companyKey != verified.companyKey ||
        !profile.canUseContactFeatures) {
      await AuthSession.instance.updateCorporateProfile(verified);
    }
    return true;
  }
}
