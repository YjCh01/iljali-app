import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/notifications/push_notification_bootstrap.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_service.dart';
import 'package:map/features/corporate/data/repositories/corporate_account_registry.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/services/corporate_org_join_service.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/services/seeker_profile_sync_service.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 내 mock 인증 세션 (로컬 저장)
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const _keyName = 'auth_name';
  static const _keyEmail = 'auth_email';
  static const _keyPhone = 'auth_phone';
  static const _keyMemberType = 'auth_member_type';
  static const _keyCorporateProfile = 'auth_corporate_profile';
  static const _keySeekerProfile = 'auth_seeker_profile';
  static const _keyAccessToken = 'auth_access_token';

  AuthUser? _user;
  String? _accessToken;

  /// Bearer token — 서버 `/v1/auth/login` 연동
  String? get accessToken => _accessToken;

  /// 기업 프로필 변경 시 UI 갱신용 (구독·플랜 전환 등)
  final ValueNotifier<int> corporateProfileRevision = ValueNotifier(0);

  /// 구직자 프로필·자격증 변경 시 UI 갱신용
  final ValueNotifier<int> seekerProfileRevision = ValueNotifier(0);

  AuthUser? get currentUser => _user;

  bool get isLoggedIn => _user != null;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyEmail);
    final name = prefs.getString(_keyName);
    final memberTypeName = prefs.getString(_keyMemberType);
    if (email == null || name == null || memberTypeName == null) return;

    MemberType memberType;
    try {
      memberType = MemberType.values.byName(memberTypeName);
    } on ArgumentError {
      await signOut();
      return;
    }

    _user = AuthUser(
      name: name,
      email: email,
      phone: prefs.getString(_keyPhone),
      memberType: memberType,
      corporateProfile: _decodeCorporateProfile(
        prefs.getString(_keyCorporateProfile),
      ),
      seekerProfile: _decodeSeekerProfile(
        prefs.getString(_keySeekerProfile),
      ),
    );
    _accessToken = prefs.getString(_keyAccessToken);
  }

  Future<void> setAccessToken(String? token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_keyAccessToken);
    } else {
      await prefs.setString(_keyAccessToken, token);
    }
  }

  SeekerMemberProfile? _decodeSeekerProfile(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SeekerMemberProfile.fromJson(map);
    } on Object {
      return null;
    }
  }

  CorporateMemberProfile? _decodeCorporateProfile(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CorporateMemberProfile.fromJson(map);
    } on Object {
      return null;
    }
  }

  Map<String, dynamic> _encodeCorporateProfile(CorporateMemberProfile profile) =>
      profile.toJson();

  Future<void> signIn(AuthUser user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, user.name);
    await prefs.setString(_keyEmail, user.email);
    await prefs.setString(_keyMemberType, user.memberType.name);
    if (user.phone != null) {
      await prefs.setString(_keyPhone, user.phone!);
    } else {
      await prefs.remove(_keyPhone);
    }
    final profile = user.corporateProfile;
    if (profile != null) {
      await prefs.setString(
        _keyCorporateProfile,
        jsonEncode(_encodeCorporateProfile(profile)),
      );
    } else {
      await prefs.remove(_keyCorporateProfile);
    }
    final seekerProfile = user.seekerProfile;
    if (seekerProfile != null) {
      await prefs.setString(
        _keySeekerProfile,
        jsonEncode(seekerProfile.toJson()),
      );
    } else {
      await prefs.remove(_keySeekerProfile);
    }
    if (user.isCorporate && user.corporateProfile != null) {
      await const CorporateOrgJoinService().syncCurrentUser();
    }
    await PushNotificationBootstrap.bindToSession();
  }

  Future<void> signOut() async {
    await PushNotificationBootstrap.clearOnSignOut();
    BusLocationTowerPilotService.invalidate();
    MapViewportSessionStore.instance.forget(MapViewportSessionKeys.corporateHome);
    MapViewportSessionStore.instance.forget(MapViewportSessionKeys.seekerHomeMap);
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyMemberType);
    await prefs.remove(_keyCorporateProfile);
    await prefs.remove(_keySeekerProfile);
    await prefs.remove(_keyAccessToken);
    _accessToken = null;
  }

  Future<({String? name, SeekerMemberProfile? profile})> readCachedSeekerSession(
    String email,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString(_keyEmail)?.trim().toLowerCase();
    final normalized = email.trim().toLowerCase();
    if (cachedEmail != normalized) {
      return (name: null, profile: null);
    }
    return (
      name: prefs.getString(_keyName),
      profile: _decodeSeekerProfile(prefs.getString(_keySeekerProfile)),
    );
  }

  Future<void> updateSeekerProfile(SeekerMemberProfile profile) async {
    final user = _user;
    if (user == null || !user.isIndividual) return;
    await SeekerProfileSyncService.persist(
      email: user.email,
      profile: profile,
    );
    seekerProfileRevision.value++;
  }

  Future<void> updateCorporateProfile(CorporateMemberProfile profile) async {
    final user = _user;
    if (user == null || !user.isCorporate) return;
    await signIn(user.copyWith(corporateProfile: profile));
    corporateProfileRevision.value++;
    await const CorporateOrgJoinService().syncCurrentUser();
  }

  /// SharedPreferences에 저장된 프로필을 세션에 다시 반영
  Future<void> reloadCorporateProfileFromStorage() async {
    final user = _user;
    if (user == null || !user.isCorporate) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = _decodeCorporateProfile(prefs.getString(_keyCorporateProfile));
    if (stored == null) return;
    _user = user.copyWith(corporateProfile: stored);
    corporateProfileRevision.value++;
  }

  /// 기업회원 로그인만 된 경우(MVP) 임시 프로필을 만들어 결제·공고 등에 사용
  Future<CorporateMemberProfile?> ensureCorporateProfile() async {
    final user = _user;
    if (user == null || !user.isCorporate) return null;

    final existing = user.corporateProfile;
    if (existing != null) return existing;

    final registry = await CorporateAccountRegistry.create();
    final profile = await registry.registerHandler(
      companyName: user.name,
      businessRegistrationNumber: _provisionalBusinessNumber(user.email),
      department: '채용',
      contactPersonName: user.name,
    );
    await updateCorporateProfile(profile);
    return profile;
  }

  String _provisionalBusinessNumber(String email) {
    final seed = email.hashCode.abs().toString();
    return seed.padLeft(10, '1').substring(0, 10);
  }
}
