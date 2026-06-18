import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';

/// 출근 상호 확인용 근무지 지오펜스 (MVP · 200m)
abstract final class AttendanceGeofenceService {
  static const radiusMeters = DeviceLocationService.checkInRadiusMeters;

  static bool get allowsRelaxedVerification =>
      DeviceLocationService.allowsRelaxedLocation;

  static AttendanceGeofenceResult evaluate({
    required GeoCoordinate? current,
    required GeoCoordinate? workplace,
    bool isMocked = false,
    bool ignoreRelaxedPlatform = false,
  }) {
    if (!ignoreRelaxedPlatform && allowsRelaxedVerification) {
      return AttendanceGeofenceResult(
        allowed: true,
        withinGeofence: true,
        distanceMeters: workplace != null && current != null
            ? GeoDistance.metersBetween(current, workplace)
            : null,
        isMocked: isMocked,
        relaxed: true,
        reason: 'relaxed_platform',
      );
    }

    if (workplace == null) {
      return AttendanceGeofenceResult(
        allowed: true,
        withinGeofence: true,
        distanceMeters: null,
        isMocked: isMocked,
        relaxed: true,
        reason: 'no_workplace',
      );
    }

    if (isMocked) {
      return AttendanceGeofenceResult(
        allowed: false,
        withinGeofence: false,
        distanceMeters: null,
        isMocked: true,
        relaxed: false,
        reason: 'mock_location',
      );
    }

    if (current == null) {
      return AttendanceGeofenceResult(
        allowed: false,
        withinGeofence: false,
        distanceMeters: null,
        isMocked: false,
        relaxed: false,
        reason: 'location_unavailable',
      );
    }

    final distance = GeoDistance.metersBetween(current, workplace);
    final within = distance <= radiusMeters;
    return AttendanceGeofenceResult(
      allowed: within,
      withinGeofence: within,
      distanceMeters: distance,
      isMocked: false,
      relaxed: false,
      reason: within ? 'within_geofence' : 'outside_geofence',
    );
  }

  static Future<AttendanceGeofenceResult> evaluateCurrent({
    required GeoCoordinate? workplace,
  }) async {
    final position = await DeviceLocationService.getCurrentPositionDetailed();
    return evaluate(
      current: position?.coordinate,
      workplace: workplace,
      isMocked: position?.isMocked ?? false,
    );
  }

  static Future<void> logVerificationAttempt({
    required String applicationId,
    required String role,
    required AttendanceGeofenceResult result,
    double? latitude,
    double? longitude,
    String? companyKey,
  }) async {
    final repo = await ComplianceRepository.create();
    await repo.logAttendanceVerification({
      'applicationId': applicationId,
      'role': role,
      'allowed': result.allowed,
      'withinGeofence': result.withinGeofence,
      'distanceMeters': result.distanceMeters,
      'isMocked': result.isMocked,
      'relaxed': result.relaxed,
      'reason': result.reason,
      'latitude': latitude,
      'longitude': longitude,
      if (companyKey != null) 'companyKey': companyKey,
    });

    if (result.isMocked) {
      await repo.addAbuseFlag({
        'type': 'mock_location_attempt',
        'severity': 'high',
        'applicationId': applicationId,
        'role': role,
        if (companyKey != null) 'companyKey': companyKey,
        'message': '모의 GPS 위치 감지 — $role 출근 확인 차단',
      });
    }
  }
}

class AttendanceGeofenceResult {
  const AttendanceGeofenceResult({
    required this.allowed,
    required this.withinGeofence,
    required this.isMocked,
    required this.relaxed,
    required this.reason,
    this.distanceMeters,
  });

  final bool allowed;
  final bool withinGeofence;
  final double? distanceMeters;
  final bool isMocked;
  final bool relaxed;
  final String reason;

  String get userMessage {
    if (relaxed) {
      return '데스크톱 환경 · 위치 확인 생략';
    }
    if (isMocked) {
      return '모의 위치가 감지되어 출근 확인할 수 없습니다.';
    }
    if (reason == 'location_unavailable') {
      return '위치 권한 또는 GPS를 확인할 수 없습니다.';
    }
    if (withinGeofence && distanceMeters != null) {
      return '근무지 반경 ${GeoDistance.formatDistanceMeters(AttendanceGeofenceService.radiusMeters)} 이내 '
          '(현재 ${GeoDistance.formatDistanceMeters(distanceMeters!)})';
    }
    if (distanceMeters != null) {
      return '근무지에서 ${GeoDistance.formatDistanceMeters(distanceMeters!)} 떨어져 있습니다 '
          '(허용 ${GeoDistance.formatDistanceMeters(AttendanceGeofenceService.radiusMeters)})';
    }
    return '근무지 반경 내에서만 출근 확인할 수 있습니다.';
  }
}
