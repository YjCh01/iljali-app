import 'package:map/features/map_dashboard/domain/entities/map_location.dart';

/// 지도 원격/로컬 데이터 소스 (추후 Geocoding API 연동)
abstract class MapRemoteDataSource {
  Future<MapLocation> fetchLocationByQuery(String query);
}
