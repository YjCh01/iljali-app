import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

/// 가짜 근무지 로컬 데이터 (추후 API 교체)
abstract class WarehouseLocalDataSource {
  Future<List<Warehouse>> fetchWarehouses();
}

class WarehouseLocalDataSourceImpl implements WarehouseLocalDataSource {
  const WarehouseLocalDataSourceImpl();

  static const List<Warehouse> _warehouses = [];

  @override
  Future<List<Warehouse>> fetchWarehouses() async =>
      List.unmodifiable(_warehouses);
}
