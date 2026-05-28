import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/data/datasources/warehouse_local_data_source.dart';
import 'package:map/features/map_dashboard/domain/entities/map_location.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/domain/repositories/map_repository.dart';

/// 지도 Repository 구현체
class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl({
    WarehouseLocalDataSource? localDataSource,
    MapCameraHolder? cameraHolder,
  })  : _localDataSource =
            localDataSource ?? const WarehouseLocalDataSourceImpl(),
        _cameraHolder = cameraHolder ?? MapCameraHolder.instance;

  final WarehouseLocalDataSource _localDataSource;
  final MapCameraHolder _cameraHolder;

  @override
  Future<MapLocation> getCurrentCenter() => _cameraHolder.getCurrentCenter();

  @override
  Future<List<Warehouse>> getWarehouses() => _localDataSource.fetchWarehouses();
}
