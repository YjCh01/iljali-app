import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';

/// 기업 지도 — 셔틀 밀도 오버레이 1건 (구직자 노출 규칙 적용 후)
class CorporateShuttleMapOverlay {
  const CorporateShuttleMapOverlay({
    required this.route,
    required this.companyKey,
    this.workplace,
  });

  /// [ShuttleRouteVisibility.forSeekerDisplay] 적용된 노선
  final CommuteRoute route;
  final String companyKey;
  final GeoCoordinate? workplace;
}
