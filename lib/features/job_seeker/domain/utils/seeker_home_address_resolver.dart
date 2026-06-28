import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 구직자 실주소 — 지도 초기 중심·거리순 정렬 기준
abstract final class SeekerHomeAddressResolver {
  static Future<GeoCoordinate> resolveMapCenter({
    SeekerMemberProfile? profile,
  }) async {
    final resolved = await resolveCoordinate(profile: profile);
    if (resolved != null) return resolved;
    const c = MapConstants.warehouseAreaCenter;
    return GeoCoordinate(latitude: c.latitude, longitude: c.longitude);
  }

  static Future<GeoCoordinate?> resolveCoordinate({
    SeekerMemberProfile? profile,
  }) async {
    final p = profile ?? AuthSession.instance.currentUser?.seekerProfile;
    if (p == null) return null;

    final stored = p.homeCoordinate;
    if (stored != null) return stored;

    final road = p.homeRoadAddress?.trim();
    if (road == null || road.isEmpty) return null;

    return AddressGeocoder.geocode(road);
  }

  static String? resolveLabel(SeekerMemberProfile? profile) {
    final p = profile ?? AuthSession.instance.currentUser?.seekerProfile;
    if (p == null) return null;
    final road = p.homeRoadAddress?.trim();
    if (road == null || road.isEmpty) return null;
    final detail = p.homeDetailAddress?.trim();
    if (detail != null && detail.isNotEmpty) return '$road $detail';
    return road;
  }
}
