import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/services/registered_business_workplace_loader.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_home_address_resolver.dart';

/// 지도 **초기 중심** 단일 정책 (PRD·제품 요구)
///
/// 1. **기업회원 기본** → 사업소재지 ([CorporateMemberProfile.businessHeadOfficeAddress])
/// 2. **개인회원 기본** → 회원정보 실주소 ([SeekerMemberProfile.homeRoadAddress])
/// 3. **기업 + 공고 행위** (수정·핀·노선 등) → 해당 공고 **근무지** → 실패 시 사업소재지
abstract final class MapInitialCenterPolicy {
  static GeoCoordinate fallback() => defaultPushMapCenter();

  static bool isFallback(GeoCoordinate coordinate) =>
      isLikelyDefaultPushMapCenter(coordinate);

  /// 기업회원 — 사업소재지
  ///
  /// [ownPosts]가 있으면 사업소재지 실패 시 **자사 공고 근무지**로 폴백
  /// (아라컴퍼니처럼 본사 좌표 미등록·지오코딩 실패해도 안성 공고로 이동).
  static Future<GeoCoordinate> corporateBusinessSite({
    CorporateMemberProfile? profile,
    List<CorporateJobPost> ownPosts = const [],
  }) async {
    profile ??= AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      return _firstOwnPostWorkplace(ownPosts) ?? fallback();
    }

    final stored = _trustedCoordinate(profile.businessHeadOfficeCoordinate);
    if (stored != null) return stored;

    final headOffice = profile.businessHeadOfficeAddress?.trim();
    if (headOffice != null && headOffice.isNotEmpty) {
      final geocoded = await _geocodeQueries(
        JobPostWorkplaceResolver.geocodeQueryCandidates(headOffice),
      );
      if (geocoded != null) return geocoded;
    }

    final loaded = await RegisteredBusinessWorkplaceLoader().load(
      profile: profile,
    );
    if (loaded.isSuccess && loaded.workplace != null) {
      final fromLoader = await _fromWorkplaceLayer(loaded.workplace);
      if (fromLoader != null) return fromLoader;
    }

    final fromPosts = await _firstOwnPostWorkplaceAsync(ownPosts);
    if (fromPosts != null) return fromPosts;

    return fallback();
  }

  static GeoCoordinate? _firstOwnPostWorkplace(List<CorporateJobPost> posts) {
    for (final post in posts) {
      final coord = _trustedCoordinate(post.workplaceCoordinate);
      if (coord != null) return coord;
    }
    return null;
  }

  static Future<GeoCoordinate?> _firstOwnPostWorkplaceAsync(
    List<CorporateJobPost> posts,
  ) async {
    final sync = _firstOwnPostWorkplace(posts);
    if (sync != null) return sync;
    for (final post in posts) {
      final fromJob = await _fromJobPostLayer(post: post);
      if (fromJob != null) return fromJob;
    }
    return null;
  }

  /// 개인회원 — 회원정보 주소지
  static Future<GeoCoordinate> seekerHome({
    SeekerMemberProfile? profile,
  }) async {
    return SeekerHomeAddressResolver.resolveMapCenter(profile: profile);
  }

  /// 기업회원 + 공고 관련 지도 — 근무지 → 사업소재지
  static Future<GeoCoordinate> corporateJobPostAction({
    CorporateJobPost? post,
    WorkplaceAddress? workplace,
    CorporateMemberProfile? profile,
  }) async {
    final fromJob = await _fromJobPostLayer(post: post, workplace: workplace);
    if (fromJob != null) return fromJob;
    return corporateBusinessSite(profile: profile);
  }

  static Future<GeoCoordinate?> _fromJobPostLayer({
    CorporateJobPost? post,
    WorkplaceAddress? workplace,
  }) async {
    final fromWorkplace = await _fromWorkplaceLayer(workplace);
    if (fromWorkplace != null) return fromWorkplace;

    if (post != null) {
      final stored = _trustedCoordinate(post.workplaceCoordinate);
      if (stored != null) return stored;

      for (final query
          in JobPostWorkplaceResolver.geocodeQueryCandidates(post.warehouseName)) {
        final geocoded = await AddressGeocoder.geocode(query);
        if (geocoded != null && !isFallback(geocoded)) return geocoded;
      }

      final fromSettings = _trustedCoordinate(
        JobPostWorkplaceResolver.coordinateFromSettings(
          post.notificationSettings,
        ),
      );
      if (fromSettings != null) return fromSettings;
    }

    return null;
  }

  static Future<GeoCoordinate?> _fromWorkplaceLayer(
    WorkplaceAddress? workplace,
  ) async {
    if (workplace == null) return null;

    final stored = _trustedCoordinate(workplace.coordinate);
    if (stored != null) return stored;

    final road = workplace.roadAddress.trim();
    if (road.isEmpty) return null;

    return _geocodeQueries(
      JobPostWorkplaceResolver.geocodeQueryCandidates(road),
    );
  }

  static Future<GeoCoordinate?> _geocodeQueries(List<String> queries) async {
    for (final query in queries) {
      final geocoded = await AddressGeocoder.geocode(query);
      if (geocoded != null && !isFallback(geocoded)) return geocoded;
    }
    return null;
  }

  static GeoCoordinate? _trustedCoordinate(GeoCoordinate? coordinate) {
    if (coordinate == null || isFallback(coordinate)) return null;
    return coordinate;
  }

  /// 동기 폴백 — async 로드 전 임시 표시용 (강남 플레이스홀더)
  static GeoCoordinate syncPlaceholder({
    GeoCoordinate? coordinate,
    GeoCoordinate? businessSiteCoordinate,
  }) {
    final trusted = _trustedCoordinate(coordinate) ??
        _trustedCoordinate(businessSiteCoordinate);
    return trusted ?? fallback();
  }

  /// @deprecated 강남 데모 중심 — [fallback] 사용
  static GeoCoordinate get legacyWarehouseDemoCenter {
    const c = MapConstants.warehouseAreaCenter;
    return GeoCoordinate(latitude: c.latitude, longitude: c.longitude);
  }
}
