import 'dart:convert';

import 'package:map/features/corporate/domain/entities/corporate_org_member.dart';
import 'package:map/features/corporate/domain/entities/corporate_org_role.dart';
import 'package:map/features/corporate/domain/entities/payment_delegation.dart';
import 'package:map/features/corporate/domain/entities/payment_delegation_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사업자번호(BRN) 단위 조직·결제 위임 저장 (MVP SharedPreferences)
class CorporateOrganizationRepository {
  CorporateOrganizationRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'corporate_organizations_v1';

  static Future<CorporateOrganizationRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CorporateOrganizationRepository(prefs);
  }

  static String normalizeCompanyKey(String businessRegistrationNumber) =>
      businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');

  Map<String, Map<String, dynamic>> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
      (k, v) => MapEntry(
        '$k',
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
      ),
    );
  }

  Future<void> _saveAll(Map<String, Map<String, dynamic>> all) async {
    await _prefs.setString(_key, jsonEncode(all));
  }

  Map<String, dynamic> _orgBucket(
    Map<String, Map<String, dynamic>> all,
    String companyKey,
  ) {
    return Map<String, dynamic>.from(all[companyKey] ?? {});
  }

  List<CorporateOrgMember> _readMembers(Map<String, dynamic> bucket) {
    final raw = bucket['members'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => CorporateOrgMember.fromJson(item.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  }

  List<PaymentDelegation> _readDelegations(Map<String, dynamic> bucket) {
    final raw = bucket['delegations'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => PaymentDelegation.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _writeOrg(
    String companyKey, {
    required List<CorporateOrgMember> members,
    required List<PaymentDelegation> delegations,
  }) async {
    final all = _loadAll();
    all[companyKey] = {
      'members': members.map((m) => m.toJson()).toList(),
      'delegations': delegations.map((d) => d.toJson()).toList(),
    };
    await _saveAll(all);
  }

  Future<List<CorporateOrgMember>> listMembers(String companyKey) async {
    final bucket = _orgBucket(_loadAll(), companyKey);
    return _readMembers(bucket);
  }

  Future<CorporateOrgMember?> findMember({
    required String companyKey,
    required String email,
  }) async {
    final normalized = email.trim().toLowerCase();
    for (final member in await listMembers(companyKey)) {
      if (member.email.trim().toLowerCase() == normalized) return member;
    }
    return null;
  }

  Future<bool> isFounder({
    required String companyKey,
    required String email,
  }) async {
    final members = await listMembers(companyKey);
    if (members.isEmpty) return false;
    return members.first.email.trim().toLowerCase() ==
        email.trim().toLowerCase();
  }

  /// 프로필 저장·가입 시 조직 자동 가입 (기존 멤버는 프로필 필드만 갱신)
  Future<CorporateOrgMember> joinMember({
    required String companyKey,
    required String email,
    required String name,
    String? handlerCode,
    String? department,
    String? contactPersonName,
    String? phone,
    CorporateOrgRole role = CorporateOrgRole.recruiter,
  }) async {
    final key = normalizeCompanyKey(companyKey);
    final all = _loadAll();
    final bucket = _orgBucket(all, key);
    final members = _readMembers(bucket);
    final delegations = _readDelegations(bucket);
    final normalized = email.trim().toLowerCase();

    final index = members.indexWhere(
      (m) => m.email.trim().toLowerCase() == normalized,
    );
    if (index >= 0) {
      members[index] = members[index].copyWith(
        name: name,
        handlerCode: handlerCode,
        department: department,
        contactPersonName: contactPersonName,
        phone: phone,
      );
    } else {
      members.add(
        CorporateOrgMember(
          email: email.trim(),
          name: name.trim(),
          role: role,
          joinedAt: DateTime.now(),
          handlerCode: handlerCode,
          department: department,
          contactPersonName: contactPersonName,
          phone: phone,
        ),
      );
    }

    await _writeOrg(key, members: members, delegations: delegations);
    return members.firstWhere(
      (m) => m.email.trim().toLowerCase() == normalized,
    );
  }

  /// 최초 가입자(대표 담당자)만 결제 권한자 역할 지정 가능
  Future<bool> assignPaymentAuthorityRole({
    required String companyKey,
    required String actorEmail,
    required String targetEmail,
  }) async {
    if (!await isFounder(companyKey: companyKey, email: actorEmail)) {
      return false;
    }
    return _updateMemberRole(
      companyKey: companyKey,
      targetEmail: targetEmail,
      role: CorporateOrgRole.paymentAuthority,
    );
  }

  Future<bool> _updateMemberRole({
    required String companyKey,
    required String targetEmail,
    required CorporateOrgRole role,
  }) async {
    final key = normalizeCompanyKey(companyKey);
    final all = _loadAll();
    final bucket = _orgBucket(all, key);
    final members = _readMembers(bucket);
    final delegations = _readDelegations(bucket);
    final normalized = targetEmail.trim().toLowerCase();
    final index = members.indexWhere(
      (m) => m.email.trim().toLowerCase() == normalized,
    );
    if (index < 0) return false;
    members[index] = members[index].copyWith(role: role);
    await _writeOrg(key, members: members, delegations: delegations);
    return true;
  }

  Future<List<PaymentDelegation>> listDelegations(String companyKey) async {
    final bucket = _orgBucket(_loadAll(), companyKey);
    return _readDelegations(bucket);
  }

  Future<String?> findAcceptedPayer({
    required String companyKey,
    required String recruiterEmail,
  }) async {
    final normalizedRecruiter = recruiterEmail.trim().toLowerCase();
    for (final delegation in await listDelegations(companyKey)) {
      if (!delegation.isActive) continue;
      if (delegation.recruiterEmail.trim().toLowerCase() == normalizedRecruiter) {
        return delegation.payerEmail;
      }
    }
    return null;
  }

  Future<List<String>> listDelegatedRecruiterEmails({
    required String companyKey,
    required String payerEmail,
  }) async {
    final normalizedPayer = payerEmail.trim().toLowerCase();
    return (await listDelegations(companyKey))
        .where(
          (d) =>
              d.isActive &&
              d.payerEmail.trim().toLowerCase() == normalizedPayer,
        )
        .map((d) => d.recruiterEmail)
        .toList();
  }

  Future<PaymentDelegation> requestDelegation({
    required String companyKey,
    required String recruiterEmail,
    required String payerEmail,
    required String requestedByEmail,
  }) async {
    final key = normalizeCompanyKey(companyKey);
    final all = _loadAll();
    final bucket = _orgBucket(all, key);
    final members = _readMembers(bucket);
    final delegations = _readDelegations(bucket);

    final recruiter = recruiterEmail.trim();
    final payer = payerEmail.trim();
    if (recruiter.toLowerCase() == payer.toLowerCase()) {
      throw StateError('same_party');
    }

    CorporateOrgMember? payerMember;
    for (final member in members) {
      if (member.email.trim().toLowerCase() == payer.trim().toLowerCase()) {
        payerMember = member;
        break;
      }
    }
    if (payerMember == null || !payerMember.isPaymentAuthority) {
      throw StateError('payer_not_authorized');
    }

    final existingIndex = delegations.indexWhere(
      (d) =>
          d.recruiterEmail.trim().toLowerCase() ==
              recruiter.trim().toLowerCase() &&
          d.payerEmail.trim().toLowerCase() == payer.trim().toLowerCase(),
    );

    final delegation = PaymentDelegation(
      recruiterEmail: recruiter,
      payerEmail: payer,
      status: PaymentDelegationStatus.pending,
      requestedAt: DateTime.now(),
      requestedByEmail: requestedByEmail.trim(),
    );

    if (existingIndex >= 0) {
      delegations[existingIndex] = delegation;
    } else {
      delegations.add(delegation);
    }

    await _writeOrg(key, members: members, delegations: delegations);
    return delegation;
  }

  Future<PaymentDelegation?> respondDelegation({
    required String companyKey,
    required String recruiterEmail,
    required String payerEmail,
    required String responderEmail,
    required bool accept,
  }) async {
    final key = normalizeCompanyKey(companyKey);
    final all = _loadAll();
    final bucket = _orgBucket(all, key);
    final members = _readMembers(bucket);
    final delegations = _readDelegations(bucket);

    final index = delegations.indexWhere(
      (d) =>
          d.recruiterEmail.trim().toLowerCase() ==
              recruiterEmail.trim().toLowerCase() &&
          d.payerEmail.trim().toLowerCase() ==
              payerEmail.trim().toLowerCase() &&
          d.status == PaymentDelegationStatus.pending,
    );
    if (index < 0) return null;

    final pending = delegations[index];
    final responder = responderEmail.trim().toLowerCase();
    final requester = pending.requestedByEmail.trim().toLowerCase();
    if (responder == requester) return null;

    final updated = pending.copyWith(
      status: accept
          ? PaymentDelegationStatus.accepted
          : PaymentDelegationStatus.rejected,
      acceptedAt: accept ? DateTime.now() : null,
    );
    delegations[index] = updated;
    await _writeOrg(key, members: members, delegations: delegations);
    return updated;
  }

  Future<List<PaymentDelegation>> bulkRequestDelegation({
    required String companyKey,
    required String payerEmail,
    required String requestedByEmail,
    required List<String> recruiterEmails,
  }) async {
    final results = <PaymentDelegation>[];
    for (final recruiter in recruiterEmails) {
      try {
        final delegation = await requestDelegation(
          companyKey: companyKey,
          recruiterEmail: recruiter,
          payerEmail: payerEmail,
          requestedByEmail: requestedByEmail,
        );
        results.add(delegation);
      } on StateError {
        continue;
      }
    }
    return results;
  }
}
