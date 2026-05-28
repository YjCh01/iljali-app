import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/domain/repositories/map_repository.dart';

/// 지도에 표시할 물류센터 목록 조회
class GetWarehousesUseCase {
  const GetWarehousesUseCase(this._repository);

  final MapRepository _repository;

  Future<List<Warehouse>> call() => _repository.getWarehouses();
}
