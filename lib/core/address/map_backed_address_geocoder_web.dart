import 'package:map/core/address/web/naver_address_geocoder_web.dart';
import 'package:map/core/geo/geo_coordinate.dart';

Future<GeoCoordinate?> geocodeWithoutRemoteAddressKeys(String query) =>
    geocodeWithNaverMaps(query);
