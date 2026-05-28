import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 프리미엄 파트너십 채팅 안내 저장 (MVP — 로컬)
class PartnershipNoticeRepository {
  PartnershipNoticeRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keySent = 'partnership_notice_sent';
  static const _keySentAt = 'partnership_notice_sent_at';
  static const _keyBody = 'partnership_notice_body';

  static Future<PartnershipNoticeRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PartnershipNoticeRepository(prefs);
  }

  Future<bool> get isSent async => _prefs.getBool(_keySent) ?? false;

  Future<String?> get body async => _prefs.getString(_keyBody);

  Future<DateTime?> get sentAt async {
    final raw = _prefs.getString(_keySentAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> sendPartnershipNotice() async {
    await _prefs.setBool(_keySent, true);
    await _prefs.setString(
      _keySentAt,
      DateTime.now().toIso8601String(),
    );
    await _prefs.setString(
      _keyBody,
      PremiumPartnershipPlans.buildChatNoticeBody(),
    );
  }
}
