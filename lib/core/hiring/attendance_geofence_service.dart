import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/core/hiring/work_schedule_time.dart';

/// 출근 상호 확인용 근무지 지오펜스 (MVP · 200m) + 근무일정 기준 시간 검증
abstract final class AttendanceGeofenceService {
  static const radiusMeters = DeviceLocationService.checkInRadiusMeters;

  /// 근무 시작 이 시간 전부터 체크인 허용
  static const earlyCheckInWindow = Duration(minutes: 30);

  static bool get allowsRelaxedVerification =>
      DeviceLocationService.allowsRelaxedLocation;

  static AttendanceGeofenceResult evaluate({
    required GeoCoordinate? current,
    required GeoCoordinate? workplace,
    bool isMocked = false,
    bool ignoreRelaxedPlatform = false,
    DateTime? workDate,
    String? workSchedule,
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

    final timeResult = _evaluateTimeWindow(
      workDate: workDate,
      workSchedule: workSchedule,
    );
    if (timeResult != null) return timeResult;

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
    DateTime? workDate,
    String? workSchedule,
  }) async {
    final position = await DeviceLocationService.getCurrentPositionDetailed();
    return evaluate(
      current: position?.coordinate,
      workplace: workplace,
      isMocked: position?.isMocked ?? false,
      workDate: workDate,
      workSchedule: workSchedule,
    );
  }

  /// 근무일정 기준 시간 검증 — 스케줄 정보가 없으면 검증을 건너뛴다(null 반환).
  static AttendanceGeofenceResult? _evaluateTimeWindow({
    DateTime? workDate,
    String? workSchedule,
  }) {
    if (workDate == null || workSchedule == null || workSchedule.trim().isEmpty) {
      return null;
    }
    final start = WorkScheduleTime.workStartAt(workDate, workSchedule);
    if (start == null) return null;

    final now = DateTime.now();
    final earliestAllowed = start.subtract(earlyCheckInWindow);
    if (now.isBefore(earliestAllowed)) {
      return const AttendanceGeofenceResult(
        allowed: false,
        withinGeofence: false,
        isMocked: false,
        relaxed: false,
        reason: 'too_early',
      );
    }

    final closesAt = WorkScheduleTime.checkWindowClosesAt(workDate, workSchedule);
    if (closesAt != null && now.isAfter(closesAt)) {
      return const AttendanceGeofenceResult(
        allowed: false,
        withinGeofence: false,
        isMocked: false,
        relaxed: false,
        reason: 'too_late',
      );
    }
    return null;
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
    if (reason == 'too_early') {
      return '아직 출근 체크 가능 시간이 아닙니다.';
    }
    if (reason == 'too_late') {
      return '출근 체크 가능 시간이 지났습니다.';
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
