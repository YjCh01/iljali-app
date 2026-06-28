import 'package:map/core/address/address_geocoder.dart';
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

  static GeoCoordinate? storedCoordinate(CorporateJobPost post) {
    final fromPost = post.workplaceCoordinate;
    if (fromPost != null) return fromPost;
    final fromSettings = coordinateFromSettings(post.notificationSettings);
    if (fromSettings == null) return null;
    final warehouse = post.warehouseName.trim();
    if (warehouse.isNotEmpty &&
        isLikelyDefaultPushMapCenter(fromSettings) &&
        !isDefaultPushMapAddressLabel(warehouse)) {
      return null;
    }
    return fromSettings;
  }

  /// 근무지 좌표 — 저장 좌표 → 알림 0번 → hint → (비동기) 지오코딩 → 기본 중심
  static GeoCoordinate resolveCoordinate(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) {
    final stored = storedCoordinate(post);
    if (stored != null) return stored;

    if (hint?.coordinate != null) return hint!.coordinate!;

    return defaultPushMapCenter();
  }

  static Future<GeoCoordinate> resolveCoordinateAsync(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) async {
    final stored = storedCoordinate(post);
    if (stored != null) return stored;

    if (hint?.coordinate != null) return hint!.coordinate!;

    final road = post.warehouseName.trim();
    if (road.isNotEmpty) {
      final geocoded = await AddressGeocoder.geocode(road);
      if (geocoded != null) return geocoded;
    }

    return defaultPushMapCenter();
  }

  static WorkplaceAddress resolve(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) {
    final coordinate = _trustedCoordinate(post, hint: hint);
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

  static GeoCoordinate? _trustedCoordinate(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) {
    final fromPost = post.workplaceCoordinate;
    if (fromPost != null && !isLikelyDefaultPushMapCenter(fromPost)) {
      return fromPost;
    }
    final fromSettings = coordinateFromSettings(post.notificationSettings);
    if (fromSettings != null &&
        !isLikelyDefaultPushMapCenter(fromSettings)) {
      return fromSettings;
    }
    final hintCoord = hint?.coordinate;
    if (hintCoord != null && !isLikelyDefaultPushMapCenter(hintCoord)) {
      return hintCoord;
    }
    return null;
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
