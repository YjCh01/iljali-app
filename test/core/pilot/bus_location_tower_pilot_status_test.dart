import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_status.dart';

void main() {
  /// 서버(Python)는 naive UTC를 'Z'/오프셋 없이 isoformat()으로 내려준다 —
  /// 테스트도 그 형태를 그대로 재현해야 파싱 로직을 제대로 검증할 수 있다.
  String naiveUtcIsoString(DateTime utc) {
    final withZ = utc.toIso8601String();
    return withZ.endsWith('Z') ? withZ.substring(0, withZ.length - 1) : withZ;
  }

  BusLocationTowerPilotStatus statusWithSession({
    required DateTime lastUpdatedAtUtc,
    bool active = true,
  }) {
    return BusLocationTowerPilotStatus(
      enabled: true,
      phase: 'sharing',
      todaySession: {
        'active': active,
        'last_latitude': 37.5,
        'last_longitude': 127.0,
        'last_updated_at': naiveUtcIsoString(lastUpdatedAtUtc),
      },
    );
  }

  test('lastLocationUpdatedAt parses naive server UTC string correctly',
      () {
    final now = DateTime.now().toUtc();
    final status = statusWithSession(lastUpdatedAtUtc: now);
    expect(status.lastLocationUpdatedAt, isNotNull);
    expect(
      status.lastLocationUpdatedAt!.difference(now).inSeconds.abs(),
      lessThan(2),
    );
  });

  test('isLocationStale is false right after an update', () {
    final status = statusWithSession(
      lastUpdatedAtUtc: DateTime.now().toUtc(),
    );
    expect(status.isLocationStale, isFalse);
  });

  test('isLocationStale is true once past the stale threshold', () {
    final status = statusWithSession(
      lastUpdatedAtUtc:
          DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    );
    expect(status.isLocationStale, isTrue);
  });

  test('isLocationStale is false when there is no live location at all', () {
    const status = BusLocationTowerPilotStatus(enabled: true);
    expect(status.hasLiveLocation, isFalse);
    expect(status.isLocationStale, isFalse);
  });

  test('lastLocationUpdatedAt is null without a session', () {
    const status = BusLocationTowerPilotStatus();
    expect(status.lastLocationUpdatedAt, isNull);
  });
}
