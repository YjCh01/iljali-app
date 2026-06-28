import 'package:geocoding/geocoding.dart';
import 'package:map/core/geo/geo_coordinate.dart';

/// iOS CLGeocoder / Android Geocoder — 서버·Kakao 키 없이 도로명 → 좌표
Future<GeoCoordinate?> geocodeWithoutRemoteAddressKeys(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;

  try {
    final locations = await locationFromAddress(trimmed);
    if (locations.isEmpty) return null;
    final first = locations.first;
    if (first.latitude == 0 && first.longitude == 0) return null;
    return GeoCoordinate(
      latitude: first.latitude,
      longitude: first.longitude,
    );
  } on Object {
    return null;
  }
}
