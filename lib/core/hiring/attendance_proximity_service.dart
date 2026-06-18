import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';

/// 근무지 300m 이내 — 출근 체크 활성화 안내 (가치업 스타일)
abstract final class AttendanceProximityService {
  static const alertRadiusMeters = 300.0;

  static bool isWithinAlertRadius({
    required GeoCoordinate current,
    required GeoCoordinate workplace,
    double radiusMeters = alertRadiusMeters,
  }) {
    return GeoDistance.metersBetween(current, workplace) <= radiusMeters;
  }

  static AttendanceProximityResult evaluate({
    required GeoCoordinate? current,
    required GeoCoordinate? workplace,
    bool isMocked = false,
    bool ignoreRelaxedPlatform = false,
  }) {
    if (!ignoreRelaxedPlatform && DeviceLocationService.allowsRelaxedLocation) {
      return AttendanceProximityResult(
        shouldPrompt: workplace != null,
        withinRadius: workplace != null,
        distanceMeters: null,
        relaxed: true,
      );
    }

    if (workplace == null || current == null) {
      return const AttendanceProximityResult(
        shouldPrompt: false,
        withinRadius: false,
      );
    }

    if (isMocked) {
      return AttendanceProximityResult(
        shouldPrompt: false,
        withinRadius: false,
        distanceMeters: GeoDistance.metersBetween(current, workplace),
        isMocked: true,
      );
    }

    final distance = GeoDistance.metersBetween(current, workplace);
    final within = distance <= alertRadiusMeters;
    return AttendanceProximityResult(
      shouldPrompt: within,
      withinRadius: within,
      distanceMeters: distance,
    );
  }
}

class AttendanceProximityResult {
  const AttendanceProximityResult({
    required this.shouldPrompt,
    required this.withinRadius,
    this.distanceMeters,
    this.relaxed = false,
    this.isMocked = false,
  });

  final bool shouldPrompt;
  final bool withinRadius;
  final double? distanceMeters;
  final bool relaxed;
  final bool isMocked;

  String get bannerMessage {
    if (relaxed) return '출근 체크 활성화 — 데스크톱·개발 환경';
    if (withinRadius) {
      return '근무지 ${GeoDistance.formatDistanceMeters(AttendanceProximityService.alertRadiusMeters)} 이내 · 출근 체크 가능';
    }
    if (distanceMeters != null) {
      return '근무지까지 ${GeoDistance.formatDistanceMeters(distanceMeters!)}';
    }
    return '위치 확인 중…';
  }
}
