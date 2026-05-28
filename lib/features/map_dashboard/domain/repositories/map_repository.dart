import 'package:map/features/map_dashboard/domain/entities/map_location.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

/// 지도 데이터 접근을 위한 추상 Repository
abstract class MapRepository {
  /// 현재 카메라 중심 위치 조회
  Future<MapLocation> getCurrentCenter();

  /// 지도에 표시할 물류센터 목록
  Future<List<Warehouse>> getWarehouses();
}
