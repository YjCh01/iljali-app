import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/data/local/local_individual_auth_store.dart';

enum AccountFindMethod { phone, email, businessNumber }

enum AccountResetMethod { phone, email }

/// 아이디·비밀번호 찾기 API
abstract final class AccountRecoveryRepository {
  static bool get _useRemoteApi => EnvConfig.isComplianceApiEnabled;

  static Future<List<String>> findEmails({
    required MemberType memberType,
    required AccountFindMethod method,
    String displayName = '',
    String contactPersonName = '',
    String phone = '',
    String? phoneVerifiedToken,
    String email = '',
    String? emailVerifiedToken,
    String companyKey = '',
  }) async {
    if (memberType == MemberType.corporate) {
      return _findCorporateEmails(
        method: method,
        contactPersonName: contactPersonName,
        companyKey: companyKey,
        email: email,
        emailVerifiedToken: emailVerifiedToken,
      );
    }
    return _findSeekerEmails(
      method: method,
      displayName: displayName,
      phone: phone,
      phoneVerifiedToken: phoneVerifiedToken,
      email: email,
      emailVerifiedToken: emailVerifiedToken,
    );
  }

  static Future<void> resetPassword({
    required MemberType memberType,
    required AccountResetMethod method,
    required String email,
    required String newPassword,
    String displayName = '',
    String contactPersonName = '',
    String companyKey = '',
    String phone = '',
    String? phoneVerifiedToken,
    String? emailVerifiedToken,
  }) async {
    if (_useRemoteApi) {
      final client = IljariApiClient();
      await client.resetPassword(
        memberType: memberType == MemberType.corporate ? 'corporate' : 'seeker',
        method: method == AccountResetMethod.email ? 'email' : 'phone',
        email: email,
        displayName: displayName,
        contactPersonName: contactPersonName,
        companyKey: companyKey,
        phone: phone,
        phoneVerifiedToken: phoneVerifiedToken,
        emailVerifiedToken: emailVerifiedToken,
        newPassword: newPassword,
      );
      return;
    }

    if (memberType != MemberType.individual) {
      throw ArgumentError('로컬 모드에서는 기업 비밀번호 재설정을 지원하지 않습니다.');
    }

    final ok = await LocalIndividualAuthStore.resetPassword(
      email: email.trim().toLowerCase(),
      phone: phone.replaceAll(RegExp(r'[^0-9]'), ''),
      newPassword: newPassword,
    );
    if (!ok) {
      throw ArgumentError('입력하신 정보와 일치하는 계정을 찾을 수 없습니다.');
    }
  }

  static Future<List<String>> _findSeekerEmails({
    required AccountFindMethod method,
    required String displayName,
    required String phone,
    String? phoneVerifiedToken,
    required String email,
    String? emailVerifiedToken,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedEmail = email.trim().toLowerCase();

    if (_useRemoteApi) {
      final client = IljariApiClient();
      final result = await client.findEmail(
        method: method == AccountFindMethod.email ? 'email' : 'phone',
        displayName: displayName,
        phone: normalizedPhone,
        phoneVerifiedToken: phoneVerifiedToken,
        email: normalizedEmail,
        emailVerifiedToken: emailVerifiedToken,
      );
      final list = result['masked_emails'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toList();
    }

    if (method == AccountFindMethod.email) {
      return LocalIndividualAuthStore.findMaskedEmailsByEmail(
        normalizedEmail,
        displayName: displayName,
      );
    }
    return LocalIndividualAuthStore.findMaskedEmailsByPhone(
      normalizedPhone,
      displayName: displayName,
    );
  }

  static Future<List<String>> _findCorporateEmails({
    required AccountFindMethod method,
    required String contactPersonName,
    required String companyKey,
    required String email,
    String? emailVerifiedToken,
  }) async {
    if (!_useRemoteApi) {
      throw ArgumentError('기업 아이디 찾기는 서버 연동 후 이용할 수 있습니다.');
    }
    final client = IljariApiClient();
    final result = await client.findCorporateEmail(
      method: method == AccountFindMethod.email ? 'email' : 'brn',
      contactPersonName: contactPersonName,
      companyKey: companyKey.replaceAll(RegExp(r'[^0-9]'), ''),
      email: email.trim().toLowerCase(),
      emailVerifiedToken: emailVerifiedToken,
    );
    final list = result['masked_emails'] as List<dynamic>? ?? [];
    return list.map((e) => e.toString()).toList();
  }
}
