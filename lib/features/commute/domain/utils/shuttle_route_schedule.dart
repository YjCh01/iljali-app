import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';

/// 노선 운행 시각·버스 이동 알림 유효 구간
abstract final class ShuttleRouteSchedule {
  static const corporateNotifyLead = Duration(minutes: 15);
  static const corporateNotifyTrail = Duration(minutes: 15);
  static const seekerTrackingLead = Duration(minutes: 30);
  static const seekerTrackingTrail = Duration(minutes: 30);

  static String? firstStopDepartureTime(CommuteRoute route) {
    final split = ShuttleRouteStopPolicy.splitRouteStops(route.stops);
    if (split.intermediate.isEmpty) return null;
    return split.intermediate.first.departureTime?.trim();
  }

  static String? workplaceArrivalTime(CommuteRoute route) {
    final split = ShuttleRouteStopPolicy.splitRouteStops(route.stops);
    return split.workplace.arrivalTime?.trim();
  }

  /// 노선 저장 전 필수 시각 검증 — null이면 OK
  static String? validateRequiredTimes(CommuteRoute route) {
    final split = ShuttleRouteStopPolicy.splitRouteStops(route.stops);
    if (split.intermediate.isEmpty) {
      return '경유 정류장을 1곳 이상 등록해 주세요.';
    }
    final firstTime = split.intermediate.first.departureTime?.trim();
    if (firstTime == null || firstTime.isEmpty) {
      return '첫 정류장 운행(탑승) 시각을 입력해 주세요.';
    }
    if (!_isValidHhMm(firstTime)) {
      return '첫 정류장 운행 시각은 HH:MM 형식이어야 합니다.';
    }
    final arrival = split.workplace.arrivalTime?.trim();
    if (arrival == null || arrival.isEmpty) {
      return '근무지 도착 시각을 입력해 주세요.';
    }
    if (!_isValidHhMm(arrival)) {
      return '근무지 도착 시각은 HH:MM 형식이어야 합니다.';
    }
    return null;
  }

  static bool _isValidHhMm(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  static DateTime? _atToday(String hhMm, DateTime now) {
    if (!_isValidHhMm(hhMm)) return null;
    final parts = hhMm.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, h, m);
  }

  /// 기업 버스 이동 알림 유효 구간 (첫 정류장 15분 전 ~ 근무지 도착 15분 후)
  static ({DateTime start, DateTime end})? corporateNotifyWindow(
    CommuteRoute route,
    DateTime now,
  ) {
    final first = firstStopDepartureTime(route);
    final arrival = workplaceArrivalTime(route);
    if (first == null || arrival == null) return null;
    final startAt = _atToday(first, now);
    final endAt = _atToday(arrival, now);
    if (startAt == null || endAt == null) return null;
    return (
      start: startAt.subtract(corporateNotifyLead),
      end: endAt.add(corporateNotifyTrail),
    );
  }

  /// 구직자 실시간 추적 유효 구간 (첫 정류장 30분 전 ~ 근무지 도착 30분 후)
  static ({DateTime start, DateTime end})? seekerTrackingWindow(
    CommuteRoute route,
    DateTime now,
  ) {
    final first = firstStopDepartureTime(route);
    final arrival = workplaceArrivalTime(route);
    if (first == null || arrival == null) return null;
    final startAt = _atToday(first, now);
    final endAt = _atToday(arrival, now);
    if (startAt == null || endAt == null) return null;
    return (
      start: startAt.subtract(seekerTrackingLead),
      end: endAt.add(seekerTrackingTrail),
    );
  }

  static bool isWithinSeekerTrackingWindow(CommuteRoute route, DateTime now) {
    final window = seekerTrackingWindow(route, now);
    if (window == null) return false;
    return !now.isBefore(window.start) && !now.isAfter(window.end);
  }

  static bool isFirstIntermediateStop(CommuteRoute route, String stopId) {
    final split = ShuttleRouteStopPolicy.splitRouteStops(route.stops);
    if (split.intermediate.isEmpty) return false;
    return split.intermediate.first.id == stopId;
  }
}
