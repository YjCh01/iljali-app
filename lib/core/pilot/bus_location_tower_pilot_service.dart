import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_status.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';

/// 어드민 지정 파일럿 — 실시간 버스 관제 참여 여부
abstract final class BusLocationTowerPilotService {
  static const _cacheTtl = Duration(minutes: 3);

  static BusLocationTowerPilotStatus? _cached;
  static DateTime? _cachedAt;

  static BusLocationTowerPilotStatus? get cached => _cached;

  static Future<BusLocationTowerPilotStatus> refresh({bool force = false}) async {
    if (!SeekerShellAccess.isSignedInSeeker ||
        !EnvConfig.isComplianceApiEnabled) {
      _cached = BusLocationTowerPilotStatus.inactive;
      _cachedAt = DateTime.now();
      return _cached!;
    }

    final now = DateTime.now();
    if (!force &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }

    try {
      final api = IljariApiClient(
        accessToken: AuthSession.instance.accessToken,
      );
      final json = await api.fetchBusLocationTowerPilotStatus();
      _cached = BusLocationTowerPilotStatus.fromJson(json);
    } on Object {
      _cached ??= BusLocationTowerPilotStatus.inactive;
    }
    _cachedAt = now;
    return _cached!;
  }

  static Future<BusLocationTowerPilotStatus> updatePosition({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final api = IljariApiClient(
      accessToken: AuthSession.instance.accessToken,
    );
    final json = await api.updateBusLocationTowerPosition(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
    );
    _cached = BusLocationTowerPilotStatus.fromJson(json);
    _cachedAt = DateTime.now();
    return _cached!;
  }

  static void invalidate() {
    _cached = null;
    _cachedAt = null;
  }
}
