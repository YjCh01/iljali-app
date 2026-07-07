import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/dev/dev_auth_service.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/dev/qc_auth_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';
import 'package:map/features/auth/data/local/local_individual_auth_store.dart';
import 'package:map/features/auth/domain/validators/name_validator.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/services/seeker_profile_sync_service.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_merge.dart';

/// 개인회원 인증 — 서버 API + 로컬 폴백
abstract final class IndividualAuthRepository {
  static bool get _useRemoteApi => EnvConfig.isComplianceApiEnabled;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final normalizedEmail = trimmedEmail.toLowerCase();

    final devAccount = DevTestAccounts.matchCredentials(
      email: trimmedEmail,
      password: password,
    );
    if (DevAuthService.isEnabled && devAccount != null) {
      if (devAccount.memberType != MemberType.individual) {
        throw ArgumentError('해당 계정은 기업회원 로그인에서 이용하세요.');
      }
      await DevAuthService.signIn(devAccount);
      return;
    }

    if (QcAuthService.isQcSeekerEmailEnabled &&
        QcAuthService.isQcSeekerEmail(normalizedEmail) &&
        password == QcAuthService.qcSeekerPassword) {
      await QcAuthService.signInSeeker(email: normalizedEmail, password: password);
      return;
    }

    if (_useRemoteApi) {
      final client = IljariApiClient();
      try {
        final result = await client.login(
          email: normalizedEmail,
          password: password,
        );
        _ensureIndividualMemberType(result);
        final token = result['access_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await AuthSession.instance.setAccessToken(token);
        }
        await _signInFromLoginResult(result, fallbackEmail: normalizedEmail);
        await QcSyncBootstrap.pullIfEnabled();
        return;
      } on IljariApiException catch (e) {
        throw ArgumentError(
          AuthErrorMessage.loginFailure(e, memberType: MemberType.individual),
        );
      }
    }

    final local = await LocalIndividualAuthStore.authenticate(
      email: normalizedEmail,
      password: password,
    );
    if (local == null) {
      throw ArgumentError('이메일 또는 비밀번호가 올바르지 않습니다.');
    }
    await _signInFromLocalRow(local);
  }

  /// 소셜 로그인·가입 API 응답으로 세션 완료
  static Future<void> completeRemoteLogin(Map<String, dynamic> result) async {
    _ensureIndividualMemberType(result);
    final token = result['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await AuthSession.instance.setAccessToken(token);
    }
    final email = (result['email'] as String?) ?? '';
    await _signInFromLoginResult(
      result,
      fallbackEmail: email,
    );
    try {
      await QcSyncBootstrap.pullIfEnabled();
    } on QcMemberSanctionException {
      rethrow;
    } on Object {
      // offline — 로그인은 유지
    }
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String phoneVerifiedToken,
    required SeekerMemberProfile seekerProfile,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (_useRemoteApi) {
      final client = IljariApiClient();
      final result = await client.signUp(
        email: normalizedEmail,
        password: password,
        phone: normalizedPhone,
        phoneVerifiedToken: phoneVerifiedToken,
        displayName: displayName.trim(),
        seekerProfile: seekerProfile.toJson(),
      );
      final token = result['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
        await AuthSession.instance.setAccessToken(token);
      }
      await _signInFromLoginResult(
        result,
        fallbackEmail: normalizedEmail,
        fallbackName: displayName.trim(),
        fallbackPhone: phone.trim(),
        fallbackProfile: seekerProfile,
      );
      await QcSyncBootstrap.pullIfEnabled();
      return;
    }

    await LocalIndividualAuthStore.register(
      email: normalizedEmail,
      password: password,
      displayName: displayName.trim(),
      phone: normalizedPhone,
      seekerProfile: seekerProfile,
    );
    await AuthSession.instance.signIn(
      AuthUser(
        name: displayName.trim(),
        email: normalizedEmail,
        phone: phone.trim(),
        memberType: MemberType.individual,
        seekerProfile: seekerProfile,
      ),
    );
  }

  static Future<List<String>> findEmails({
    required String phone,
    required String phoneVerifiedToken,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (_useRemoteApi) {
      final client = IljariApiClient();
      final result = await client.findEmail(
        phone: normalizedPhone,
        phoneVerifiedToken: phoneVerifiedToken,
      );
      final list = result['masked_emails'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toList();
    }
    return LocalIndividualAuthStore.findMaskedEmailsByPhone(normalizedPhone);
  }

  static Future<void> resetPassword({
    required String email,
    required String phone,
    required String phoneVerifiedToken,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (_useRemoteApi) {
      final client = IljariApiClient();
      await client.resetPassword(
        email: normalizedEmail,
        phone: normalizedPhone,
        phoneVerifiedToken: phoneVerifiedToken,
        newPassword: newPassword,
      );
      return;
    }

    final ok = await LocalIndividualAuthStore.resetPassword(
      email: normalizedEmail,
      phone: normalizedPhone,
      newPassword: newPassword,
    );
    if (!ok) {
      throw ArgumentError('이메일과 휴대폰 번호가 일치하는 계정을 찾을 수 없습니다.');
    }
  }

  static void _ensureIndividualMemberType(Map<String, dynamic> result) {
    final memberType = (result['member_type'] as String?)?.trim() ?? '';
    if (memberType == 'corporate' || memberType == 'employer') {
      throw ArgumentError('기업회원 계정입니다. 기업회원 로그인을 이용하세요.');
    }
    if (memberType.isNotEmpty && memberType != 'seeker') {
      throw ArgumentError('개인회원 계정이 아닙니다.');
    }
  }

  @visibleForTesting
  static String loginErrorMessageForTest(IljariApiException error) =>
      AuthErrorMessage.loginFailure(error, memberType: MemberType.individual);

  static Future<void> _signInFromLoginResult(
    Map<String, dynamic> result, {
    required String fallbackEmail,
    String? fallbackName,
    String? fallbackPhone,
    SeekerMemberProfile? fallbackProfile,
  }) async {
    final email = (result['email'] as String?) ?? fallbackEmail;
    final normalizedEmail = email.trim().toLowerCase();

    SeekerMemberProfile? fromServer;
    final rawProfile = result['seeker_profile'];
    if (rawProfile is Map<String, dynamic>) {
      fromServer = SeekerMemberProfile.fromJson(rawProfile);
    }

    final cached = await AuthSession.instance.readCachedSeekerSession(
      normalizedEmail,
    );
    final localStoreProfile =
        await LocalIndividualAuthStore.seekerProfileForEmail(normalizedEmail);
    final localStoreName =
        await LocalIndividualAuthStore.displayNameForEmail(normalizedEmail);

    final displayName = _resolveDisplayName(
      serverName: (result['display_name'] as String?) ?? fallbackName,
      cachedName: cached.name ?? localStoreName,
      fallbackName: fallbackName,
      email: normalizedEmail,
    );

    final profile = SeekerProfileMerge.mergePreferRicher(
      [
        fromServer,
        cached.profile,
        localStoreProfile,
        fallbackProfile,
      ],
      displayName: displayName,
    );

    final phone = (result['phone'] as String?) ?? fallbackPhone ?? '';

    await AuthSession.instance.signIn(
      AuthUser(
        name: displayName,
        email: normalizedEmail,
        phone: phone,
        memberType: MemberType.individual,
        seekerProfile: profile,
      ),
    );

    final serverScore = SeekerProfileMerge.richnessScore(
      fromServer ?? const SeekerMemberProfile(phoneVerified: false),
      displayName: displayName,
    );
    final mergedScore = SeekerProfileMerge.richnessScore(
      profile,
      displayName: displayName,
    );
    if (mergedScore > serverScore) {
      await SeekerProfileSyncService.persist(
        email: normalizedEmail,
        profile: profile,
        displayName: displayName,
      );
    } else {
      await LocalIndividualAuthStore.updateSeekerProfile(
        email: normalizedEmail,
        seekerProfile: profile,
      );
    }
  }

  static String _resolveDisplayName({
    required String? serverName,
    required String? cachedName,
    required String? fallbackName,
    required String email,
  }) {
    for (final candidate in [serverName, cachedName, fallbackName]) {
      if (NameValidator.validate(candidate).isValid) {
        return candidate!.trim();
      }
    }
    return (serverName?.trim().isNotEmpty ?? false)
        ? serverName!.trim()
        : email.split('@').first;
  }

  static Future<void> _signInFromLocalRow(Map<String, dynamic> row) async {
    final profileRaw = row['seekerProfile'];
    final profile = profileRaw is Map<String, dynamic>
        ? SeekerMemberProfile.fromJson(profileRaw)
        : const SeekerMemberProfile(phoneVerified: true);

    await AuthSession.instance.signIn(
      AuthUser(
        name: row['displayName'] as String? ?? '',
        email: row['email'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        memberType: MemberType.individual,
        seekerProfile: profile,
      ),
    );
  }

  @visibleForTesting
  static void ensureIndividualMemberTypeForTest(Map<String, dynamic> result) =>
      _ensureIndividualMemberType(result);
}
