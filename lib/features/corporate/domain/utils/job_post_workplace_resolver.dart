import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 공고 근무지 — 사업자 본사 주소가 아닌 [warehouseName]·알림 설정 0번 거점 기준
abstract final class JobPostWorkplaceResolver {
  static GeoCoordinate? coordinateFromSettings(
    JobPostNotificationSettings? settings,
  ) {
    if (settings == null || settings.basePoints.isEmpty) return null;
    return settings.basePoints.first.coordinate;
  }

  /// 근무지 좌표 — 알림 설정 0번 → [hint] → 기본 지도 중심 (본사 주소 사용 금지)
  static GeoCoordinate resolveCoordinate(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) {
    final fromSettings = coordinateFromSettings(post.notificationSettings);
    if (fromSettings != null) return fromSettings;

    if (hint?.coordinate != null) return hint!.coordinate!;

    return defaultPushMapCenter();
  }

  static WorkplaceAddress resolve(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) {
    final coordinate = resolveCoordinate(post, hint: hint);
    final road = post.warehouseName.trim().isNotEmpty
        ? post.warehouseName.trim()
        : (hint?.roadAddress ?? '근무지');
    return WorkplaceAddress(
      roadAddress: road,
      coordinate: coordinate,
      detailAddress: hint?.detailAddress,
      jibunAddress: hint?.jibunAddress,
      dongName: hint?.dongName,
    );
  }

  /// 셔틀 노선 근무지(마지막 정류장) — 알림핀·노선 연결 시 폴백
  static GeoCoordinate? workplaceFromRouteStops(
    List<CommuteRouteStop> stops,
  ) {
    if (stops.isEmpty) return null;
    final split = ShuttleRouteStopPolicy.splitRouteStops(stops);
    return split.workplace.coordinate;
  }
}
