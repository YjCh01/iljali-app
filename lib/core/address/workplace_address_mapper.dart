import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

abstract final class WorkplaceAddressMapper {
  static WorkplaceAddress fromDaumPostcode(
    DataModel result, {
    GeoCoordinate? coordinate,
  }) {
    final road = result.roadAddress.trim().isNotEmpty
        ? result.roadAddress.trim()
        : result.address.trim();
    final jibun = result.jibunAddress.trim().isNotEmpty
        ? result.jibunAddress.trim()
        : null;
    final building = result.buildingName.trim().isNotEmpty
        ? result.buildingName.trim()
        : null;
    final dong = result.bname.trim().isNotEmpty ? result.bname.trim() : null;
    final zip = result.zonecode.trim().isNotEmpty ? result.zonecode.trim() : null;

    return WorkplaceAddress(
      roadAddress: road,
      jibunAddress: jibun,
      dongName: dong,
      buildingName: building,
      zipCode: zip,
      coordinate: coordinate,
    );
  }
}
