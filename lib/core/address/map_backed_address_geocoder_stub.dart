import 'package:map/core/geo/geo_coordinate.dart';

/// Kakao/JUSO 서버 키 없이 주소 → 좌표 (웹·네이티브 각각 구현)
Future<GeoCoordinate?> geocodeWithoutRemoteAddressKeys(String query) async =>
    null;
