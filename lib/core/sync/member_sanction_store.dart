import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// sync bootstrap의 member_status → 로컬 제재 상태 (지원 제한·교육 팝업 등)
class MemberSanctionStore {
  MemberSanctionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'member_sanction_';

  static Future<MemberSanctionStore> create() async {
    return MemberSanctionStore(await SharedPreferences.getInstance());
  }

  String _key(String email) => '$_prefix${email.trim().toLowerCase()}';

  Future<void> saveFromBootstrap(String email, Map<String, dynamic>? status) async {
    if (email.trim().isEmpty) return;
    if (status == null) {
      await _prefs.remove(_key(email));
      return;
    }
    await _prefs.setString(_key(email), jsonEncode(status));
  }

  Map<String, dynamic>? snapshot(String email) {
    final raw = _prefs.getString(_key(email));
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  bool isApplyRestricted(String email) {
    final status = snapshot(email);
    if (status == null) return false;
    if (status['is_suspended'] == true || status['is_permanently_banned'] == true) {
      return true;
    }
    final restrictions = status['restrictions'];
    if (restrictions is! Map) return false;
    final untilRaw = restrictions['apply_restriction_until'];
    if (untilRaw == null) return false;
    final until = DateTime.tryParse('$untilRaw');
    return until != null && DateTime.now().isBefore(until);
  }

  String? applyRestrictionMessage(String email) {
    if (!isApplyRestricted(email)) return null;
    final status = snapshot(email);
    final tier = status?['sanction_tier'] as String? ?? '';
    if (tier == 'caution') {
      return '주의 조치로 3일간 지원이 제한됩니다.';
    }
    if (tier == 'warning') {
      return '경고 조치로 14일간 지원이 제한됩니다.';
    }
    return status?['sanction_reason'] as String? ?? '이용 제한으로 지원할 수 없습니다.';
  }

  bool isVaultRestricted(String email) {
    final restrictions = snapshot(email)?['restrictions'];
    if (restrictions is! Map) return false;
    return restrictions['vault_limit'] == true;
  }

  bool isPushRestricted(String email) {
    final restrictions = snapshot(email)?['restrictions'];
    if (restrictions is! Map) return false;
    return restrictions['push_limit'] == true;
  }

  String? vaultRestrictionMessage(String email) {
    if (!isVaultRestricted(email)) return null;
    return '경고 조치로 보관함 이용이 제한됩니다.';
  }

  bool shouldShowEducationPopup(String email) {
    final status = snapshot(email);
    if (status == null) return false;
    final restrictions = status['restrictions'];
    if (restrictions is! Map) return false;
    return restrictions['education_popup'] == true;
  }

  Future<void> clearEducationPopup(String email) async {
    final status = snapshot(email);
    if (status == null) return;
    final restrictions = status['restrictions'];
    if (restrictions is Map) {
      final copy = Map<String, dynamic>.from(restrictions);
      copy.remove('education_popup');
      status['restrictions'] = copy;
      await _prefs.setString(_key(email), jsonEncode(status));
    }
  }
}
