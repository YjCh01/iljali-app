import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3연속 노쇼 → 블랙리스트 · 지도 직접 열람 3회/일
class SeekerNoShowBlacklistService {
  SeekerNoShowBlacklistService(this._prefs);

  final SharedPreferences _prefs;

  static const consecutiveThreshold = 3;
  static const mapBrowseDailyLimit = 3;

  static Future<SeekerNoShowBlacklistService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerNoShowBlacklistService(prefs);
  }

  String _blacklistKey(String email) => 'seeker_blacklist_${email.toLowerCase()}';

  String _mapBrowseKey(String email) {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return 'seeker_map_browse_${email.toLowerCase()}_$day';
  }

  Future<bool> isBlacklisted(String seekerEmail) async {
    return _prefs.getBool(_blacklistKey(seekerEmail)) ?? false;
  }

  Future<int> remainingMapBrowsesToday(String seekerEmail) async {
    if (!await isBlacklisted(seekerEmail)) return mapBrowseDailyLimit;
    final used = _prefs.getInt(_mapBrowseKey(seekerEmail)) ?? 0;
    return (mapBrowseDailyLimit - used).clamp(0, mapBrowseDailyLimit);
  }

  Future<bool> consumeMapBrowse(String seekerEmail) async {
    if (!await isBlacklisted(seekerEmail)) return true;
    final key = _mapBrowseKey(seekerEmail);
    final used = _prefs.getInt(key) ?? 0;
    if (used >= mapBrowseDailyLimit) return false;
    await _prefs.setInt(key, used + 1);
    return true;
  }

  Future<SeekerNoShowRecordResult> recordEmployerNoShow({
    required String seekerEmail,
    required LocalHiringRepository hiringRepo,
  }) async {
    final streak = await consecutiveNoShowCount(seekerEmail, hiringRepo);
    if (EnvConfig.isComplianceApiEnabled) {
      final client = IljariApiClient();
      if (client.isEnabled) {
        await client.syncSeekerNoShowSanction(
          seekerEmail: seekerEmail,
          streak: streak,
        );
      }
    }
    if (streak >= consecutiveThreshold) {
      await _prefs.setBool(_blacklistKey(seekerEmail), true);
      return SeekerNoShowRecordResult(
        consecutiveCount: streak,
        blacklisted: true,
      );
    }
    return SeekerNoShowRecordResult(
      consecutiveCount: streak,
      blacklisted: false,
    );
  }

  Future<int> consecutiveNoShowCount(
    String seekerEmail,
    LocalHiringRepository hiringRepo,
  ) async {
    final apps = await hiringRepo.fetchForSeeker(seekerEmail);
    apps.sort((a, b) {
      final ad = a.workDate ?? a.appliedAt;
      final bd = b.workDate ?? b.appliedAt;
      return bd.compareTo(ad);
    });

    var streak = 0;
    for (final app in apps) {
      if (app.agreementCancelledAt != null) continue;
      if (app.scheduleChangedAt != null) continue;

      final isNoShow = app.status == HiringApplicationStatus.noShow ||
          app.noShowMarkedAt != null;
      if (isNoShow) {
        streak++;
        continue;
      }

      if (app.status == HiringApplicationStatus.commissionPaid ||
          (app.isMutuallyConfirmed &&
              app.status == HiringApplicationStatus.checkedIn)) {
        break;
      }
      if (app.isWorkAgreementComplete &&
          app.status == HiringApplicationStatus.scheduled) {
        break;
      }
    }
    return streak;
  }
}

class SeekerNoShowRecordResult {
  const SeekerNoShowRecordResult({
    required this.consecutiveCount,
    required this.blacklisted,
  });

  final int consecutiveCount;
  final bool blacklisted;
}
