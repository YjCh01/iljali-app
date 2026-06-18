import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// 셔틀 노선 정류장 — 경유 정류장 + 말단 근무지
abstract final class ShuttleRouteStopPolicy {
  static const workplaceStopId = '__shuttle_workplace__';
  static const workplaceLabel = '근무지';
  static const workplaceAdjustIndex = -2;

  /// 경유 정류장 상한 (근무지 1곳 별도)
  static int get maxIntermediateStops => CommuteRoute.maxStopsPerRoute - 1;

  static bool isWorkplaceStop(CommuteRouteStop stop) =>
      stop.id == workplaceStopId ||
      stop.label.trim() == workplaceLabel;

  /// PUSH 이용권 발송 대상 — 셔틀 말단 근무지 제외
  static bool isPushEligibleShuttleStop(CommuteRouteStop stop) =>
      !isWorkplaceStop(stop);

  static Iterable<CommuteRouteStop> pushEligibleStops(
    Iterable<CommuteRouteStop> stops,
  ) =>
      stops.where(isPushEligibleShuttleStop);

  /// 노선 정류장 ID 목록 — 말단 근무지 제외 (등록·결제 저장용)
  static List<String> filterRegistrableStopIds({
    required Iterable<String> stopIds,
    required Iterable<CommuteRouteStop> routeStops,
  }) {
    final byId = {for (final stop in routeStops) stop.id: stop};
    return [
      for (final id in stopIds)
        if (byId[id] != null && isPushEligibleShuttleStop(byId[id]!)) id,
    ];
  }

  static CommuteRouteStop defaultWorkplace({GeoCoordinate? coordinate}) {
    return CommuteRouteStop(
      id: workplaceStopId,
      label: workplaceLabel,
      coordinate: coordinate ?? defaultPushMapCenter(),
    );
  }

  static GeoCoordinate defaultPushMapCenter() =>
      const GeoCoordinate(latitude: 37.5012, longitude: 127.0396);

  static ({List<CommuteRouteStop> intermediate, CommuteRouteStop workplace})
      splitRouteStops(List<CommuteRouteStop> stops) {
    if (stops.isEmpty) {
      return (intermediate: <CommuteRouteStop>[], workplace: defaultWorkplace());
    }

    final workplaceIndex = stops.indexWhere(isWorkplaceStop);
    if (workplaceIndex >= 0) {
      final workplace = stops[workplaceIndex];
      final intermediate = [
        for (var i = 0; i < stops.length; i++)
          if (i != workplaceIndex) stops[i],
      ];
      return (
        intermediate: intermediate,
        workplace: workplace.copyWith(
          label: workplaceLabel,
          departureTime: null,
        ),
      );
    }

    final last = stops.last;
    final intermediate = stops.length <= 1
        ? <CommuteRouteStop>[]
        : stops.sublist(0, stops.length - 1);
    return (
      intermediate: intermediate,
      workplace: CommuteRouteStop(
        id: workplaceStopId,
        label: workplaceLabel,
        coordinate: last.coordinate,
        photoPath: last.photoPath,
        exposureActivated: last.exposureActivated,
      ),
    );
  }

  static List<CommuteRouteStop> mergeStops(
    List<CommuteRouteStop> intermediate,
    CommuteRouteStop workplace,
  ) {
    return [
      ...intermediate,
      CommuteRouteStop(
        id: workplaceStopId,
        label: workplaceLabel,
        coordinate: workplace.coordinate,
        photoPath: workplace.photoPath,
        exposureActivated: workplace.exposureActivated,
      ),
    ];
  }

  static int intermediateCount(List<CommuteRouteStop> allStops) {
    final split = splitRouteStops(allStops);
    return split.intermediate.length;
  }
}
