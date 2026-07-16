import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/dev/dev_auth_service.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/services/corporate_org_join_service.dart';

/// 기업회원 인증 — 서버 API 연동
abstract final class CorporateAuthRepository {
  static bool get _useRemoteApi => EnvConfig.isComplianceApiEnabled;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final devAccount = DevTestAccounts.matchCredentials(
      email: email.trim(),
      password: password,
    );
    if (DevAuthService.isEnabled && devAccount != null) {
      if (devAccount.memberType != MemberType.corporate) {
        throw ArgumentError('해당 계정은 개인회원 로그인에서 이용하세요.');
      }
      await DevAuthService.signIn(devAccount);
      return;
    }

    if (!_useRemoteApi) {
      throw ArgumentError(
        '기업 로그인은 서버 연동(COMPLIANCE_API_URL) 설정 후 이용할 수 있습니다.',
      );
    }

    final client = IljariApiClient();
    Map<String, dynamic> result;
    try {
      result = await client.login(
        email: normalizedEmail,
        password: password,
      );
    } on IljariApiException catch (e) {
      throw ArgumentError(
        AuthErrorMessage.loginFailure(e, memberType: MemberType.corporate),
      );
    }
    final memberType = result['member_type'] as String? ?? '';
    if (memberType == 'seeker') {
      throw ArgumentError('개인회원 계정입니다. 개인 로그인을 이용하세요.');
    }
    if (memberType != 'corporate' && memberType != 'employer') {
      throw ArgumentError('기업회원 계정이 아닙니다.');
    }

    final token = result['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await AuthSession.instance.setAccessToken(token);
    }
    await _signInFromLoginResult(result, fallbackEmail: normalizedEmail);
    await const CorporateOrgJoinService().syncCurrentUser();
    await QcSyncBootstrap.pullIfEnabled();
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String phoneVerifiedToken,
    required CorporateMemberProfile profile,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (!_useRemoteApi) {
      throw ArgumentError(
        '기업 가입은 서버 연동(COMPLIANCE_API_URL) 설정 후 이용할 수 있습니다.',
      );
    }

    final client = IljariApiClient();
    final result = await client.signUpCorporate(
      email: normalizedEmail,
      password: password,
      displayName: displayName.trim(),
      phone: normalizedPhone,
      phoneVerifiedToken: phoneVerifiedToken,
      companyName: profile.companyName,
      companyKey: profile.companyKey,
      department: profile.department,
      contactPersonName: profile.contactPersonName,
      handlerCode: profile.handlerCode,
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
      fallbackProfile: profile,
    );
    await const CorporateOrgJoinService().syncCurrentUser();
    await QcSyncBootstrap.pullIfEnabled();
  }

  /// 소셜 로그인 콜백에서 이미 발급된 access_token + 회원 정보로 세션을 완료.
  static Future<void> completeSocialLogin(Map<String, dynamic> result) async {
    final token = result['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await AuthSession.instance.setAccessToken(token);
    }
    await _signInFromLoginResult(
      result,
      fallbackEmail: result['email'] as String? ?? '',
    );
    await const CorporateOrgJoinService().syncCurrentUser();
    await QcSyncBootstrap.pullIfEnabled();
  }

  static Future<void> signUpSocial({
    required String socialToken,
    required String displayName,
    required String phone,
    required String phoneVerifiedToken,
    required CorporateMemberProfile profile,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (!_useRemoteApi) {
      throw ArgumentError(
        '기업 가입은 서버 연동(COMPLIANCE_API_URL) 설정 후 이용할 수 있습니다.',
      );
    }

    final client = IljariApiClient();
    final result = await client.socialSignupCorporate(
      socialToken: socialToken,
      phone: normalizedPhone,
      phoneVerifiedToken: phoneVerifiedToken,
      displayName: displayName.trim(),
      companyName: profile.companyName,
      companyKey: profile.companyKey,
      department: profile.department,
      contactPersonName: profile.contactPersonName,
      handlerCode: profile.handlerCode,
    );

    final token = result['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      await AuthSession.instance.setAccessToken(token);
    }
    await _signInFromLoginResult(
      result,
      fallbackEmail: result['email'] as String? ?? '',
      fallbackName: displayName.trim(),
      fallbackPhone: phone.trim(),
      fallbackProfile: profile,
    );
    await const CorporateOrgJoinService().syncCurrentUser();
    await QcSyncBootstrap.pullIfEnabled();
  }

  static Future<void> _signInFromLoginResult(
    Map<String, dynamic> result, {
    required String fallbackEmail,
    String? fallbackName,
    String? fallbackPhone,
    CorporateMemberProfile? fallbackProfile,
  }) async {
    final email = (result['email'] as String?) ?? fallbackEmail;
    final displayName = (result['display_name'] as String?) ??
        fallbackName ??
        email.split('@').first;
    final phone = (result['phone'] as String?) ?? fallbackPhone ?? '';
    final companyKey =
        (result['company_key'] as String?) ?? fallbackProfile?.companyKey ?? '';
    final companyName = (result['company_name'] as String?) ??
        fallbackProfile?.companyName ??
        '';
    final department = (result['department'] as String?) ??
        fallbackProfile?.department ??
        '';
    final contactPersonName = (result['contact_person_name'] as String?) ??
        fallbackProfile?.contactPersonName ??
        displayName;
    final handlerCode = (result['handler_code'] as String?) ??
        fallbackProfile?.handlerCode ??
        '';

    final profile = CorporateMemberProfile(
      companyName: companyName.isNotEmpty
          ? companyName
          : (fallbackProfile?.companyName ?? '기업'),
      businessRegistrationNumber: companyKey.isNotEmpty
          ? companyKey
          : (fallbackProfile?.businessRegistrationNumber ?? ''),
      department: department.isNotEmpty
          ? department
          : (fallbackProfile?.department ?? ''),
      contactPersonName: contactPersonName.isNotEmpty
          ? contactPersonName
          : (fallbackProfile?.contactPersonName ?? displayName),
      handlerCode: handlerCode.isNotEmpty
          ? handlerCode
          : (fallbackProfile?.handlerCode ?? ''),
      entityType: fallbackProfile?.entityType ?? BusinessEntityType.corporation,
      verificationStatus: fallbackProfile?.verificationStatus ??
          BusinessVerificationStatus.pending,
      requiresAdminReview: fallbackProfile?.requiresAdminReview ?? false,
      adminReviewApproved: fallbackProfile?.adminReviewApproved ?? false,
      adminReviewReason: fallbackProfile?.adminReviewReason,
      certificateImageRef: fallbackProfile?.certificateImageRef,
      industryName: fallbackProfile?.industryName,
      policyAcceptedAt: fallbackProfile?.policyAcceptedAt,
      termsVersionAccepted: fallbackProfile?.termsVersionAccepted,
      privacyVersionAccepted: fallbackProfile?.privacyVersionAccepted,
      outsourcingPolicyVersionAccepted:
          fallbackProfile?.outsourcingPolicyVersionAccepted,
    );

    await AuthSession.instance.signIn(
      AuthUser(
        name: displayName,
        email: email,
        phone: phone.isEmpty ? null : phone,
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );
  }
}
