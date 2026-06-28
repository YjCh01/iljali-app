import 'package:flutter/foundation.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/dev/dev_test_data_seeder.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// QC 가상 구직자 · 서버 연동 로그인
abstract final class QcAuthService {
  static final _seekerEmail =
      RegExp(r'^seeker-\d{4}@qc\.iljari\.co\.kr$', caseSensitive: false);

  static const qcSeekerPassword = 'QcTest1234!';

  static bool get isQcSeekerEmailEnabled =>
      kDebugMode && (EnvConfig.qcMode || EnvConfig.isComplianceApiEnabled);

  static bool isQcSeekerEmail(String email) =>
      _seekerEmail.hasMatch(email.trim().toLowerCase());

  static Future<void> signInSeeker({
    required String email,
    required String password,
  }) async {
    if (!isQcSeekerEmailEnabled) {
      throw StateError('QC seeker login is debug-only');
    }
    final normalized = email.trim().toLowerCase();
    if (!isQcSeekerEmail(normalized)) {
      throw ArgumentError('QC 구직자 이메일 형식이 아닙니다.');
    }
    if (password != qcSeekerPassword) {
      throw ArgumentError('비밀번호가 올바르지 않습니다.');
    }

    if (EnvConfig.isComplianceApiEnabled) {
      try {
        final client = IljariApiClient();
        final result = await client.login(
          email: normalized,
          password: password,
        );
        final token = result['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await AuthSession.instance.setAccessToken(token);
        }
        final displayName = (result['display_name'] as String?) ??
            normalized.split('@').first.replaceAll('-', ' ').toUpperCase();
        await AuthSession.instance.signIn(
          AuthUser(
            name: displayName,
            email: normalized,
            phone: result['phone'] as String? ?? '010-3000-0000',
            memberType: MemberType.individual,
            seekerProfile: SeekerMemberProfile(
              phoneVerified: true,
              onboardingCompletedAt: DateTime(2026, 1, 1),
            ),
          ),
        );
        await QcSyncBootstrap.pullIfEnabled();
        return;
      } on Object {
        // fallback to local QC login below
      }
    }

    final displayName = normalized.split('@').first.replaceAll('-', ' ').toUpperCase();
    await AuthSession.instance.signIn(
      AuthUser(
        name: displayName,
        email: normalized,
        phone: '010-3000-0000',
        memberType: MemberType.individual,
        seekerProfile: SeekerMemberProfile(
          phoneVerified: true,
          onboardingCompletedAt: DateTime(2026, 1, 1),
        ),
      ),
    );
    await QcSyncBootstrap.pullIfEnabled();
  }

  static Future<void> signInCorporateFromDev({
    required String email,
    required CorporateMemberProfile profile,
    required String displayName,
    String? phone,
  }) async {
    await DevTestDataSeeder.ensureSeeded();
    await AuthSession.instance.signIn(
      AuthUser(
        name: displayName,
        email: email,
        phone: phone,
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );
    await PushWalletService().loadWalletDetailed(profile);
    await QcSyncBootstrap.pullIfEnabled();
  }
}
