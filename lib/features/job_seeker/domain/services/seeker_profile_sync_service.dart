import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/auth/data/local/local_individual_auth_store.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 구직자 프로필 — 세션·로컬·서버 동기화
abstract final class SeekerProfileSyncService {
  static bool get _useRemoteApi => EnvConfig.isComplianceApiEnabled;

  static Future<void> persist({
    required String email,
    required SeekerMemberProfile profile,
    String? displayName,
  }) async {
    final user = AuthSession.instance.currentUser;
    if (user != null && user.email.trim().toLowerCase() == email.trim().toLowerCase()) {
      await AuthSession.instance.signIn(
        user.copyWith(
          name: displayName ?? user.name,
          seekerProfile: profile,
        ),
      );
    }

    await LocalIndividualAuthStore.updateSeekerProfile(
      email: email,
      seekerProfile: profile,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await LocalIndividualAuthStore.updateDisplayName(
        email: email,
        displayName: displayName.trim(),
      );
    }

    await _pushToServer(profile, displayName: displayName);
  }

  static Future<void> _pushToServer(
    SeekerMemberProfile profile, {
    String? displayName,
  }) async {
    if (!_useRemoteApi) return;
    final token = AuthSession.instance.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final client = IljariApiClient(accessToken: token);
      await client.updateSeekerProfile(
        profile.toJson(),
        displayName: displayName,
      );
    } on Object {
      // 오프라인·API 미배포 시 로컬 저장만 유지
    }
  }
}
