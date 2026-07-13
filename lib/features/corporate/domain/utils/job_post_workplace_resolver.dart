import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/map_initial_center_policy.dart';
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

  static GeoCoordinate? storedCoordinate(CorporateJobPost post) =>
      _trustedCoordinate(post);

  /// 지도·공고 소재지 — 저장 좌표 → 알림 설정 0번(근무지) → 지오코딩 → 사업소재지
  static GeoCoordinate resolveMapWorkplaceCoordinate(CorporateJobPost post) {
    return _trustedCoordinate(post) ??
        MapInitialCenterPolicy.syncPlaceholder(
          businessSiteCoordinate:
              post.registeredBy?.businessHeadOfficeCoordinate,
        );
  }

  static Future<GeoCoordinate> resolveMapWorkplaceCoordinateAsync(
    CorporateJobPost post,
  ) =>
      MapInitialCenterPolicy.corporateJobPostAction(post: post);

  static List<String> geocodeQueryCandidates(String warehouseName) {
    final trimmed = warehouseName.trim();
    if (trimmed.isEmpty) return const [];

    final queries = <String>[trimmed];
    final withoutParen = trimmed
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (withoutParen.isNotEmpty && withoutParen != trimmed) {
      queries.add(withoutParen);
    }

    final source = withoutParen.isNotEmpty ? withoutParen : trimmed;

    // 상세주소·건물번호만 덧붙인 꼬리 제거 (예: "…소동산길 3-29 1234")
    final withoutDetailTail = source
        .replaceFirst(RegExp(r'\s+\d{1,5}$'), '')
        .trim();
    if (withoutDetailTail.length >= 6 &&
        withoutDetailTail != source &&
        !queries.contains(withoutDetailTail)) {
      queries.add(withoutDetailTail);
    }

    final lotNumber = RegExp(r'\d+(?:-\d+)?').firstMatch(source);
    if (lotNumber != null) {
      final roadOnly = source.substring(0, lotNumber.end).trim();
      if (roadOnly.length >= 6 && !queries.contains(roadOnly)) {
        queries.add(roadOnly);
      }
    }
    return queries;
  }

  static GeoCoordinate? _workplaceStoredCoordinate(CorporateJobPost post) {
    final fromPost = post.workplaceCoordinate;
    if (fromPost != null && !isLikelyDefaultPushMapCenter(fromPost)) {
      return fromPost;
    }
    return null;
  }

  /// 근무지 좌표 — 저장 좌표 → 알림 0번 → hint → (비동기) 지오코딩 → 기본 중심
  static GeoCoordinate resolveCoordinate(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) {
    final stored = _trustedCoordinate(post, hint: hint);
    if (stored != null) return stored;

    return MapInitialCenterPolicy.syncPlaceholder(
      coordinate: hint?.coordinate,
      businessSiteCoordinate: post.registeredBy?.businessHeadOfficeCoordinate,
    );
  }

  static Future<GeoCoordinate> resolveCoordinateAsync(
    CorporateJobPost post, {
    WorkplaceAddress? hint,
  }) =>
      MapInitialCenterPolicy.corporateJobPostAction(
        post: post,
        workplace: hint,
      );

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
