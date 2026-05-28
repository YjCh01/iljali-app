import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/domain/repositories/map_repository.dart';

/// 물류센터 이름·공고 요약으로 로컬 검색
class SearchWarehousesUseCase {
  const SearchWarehousesUseCase(this._repository);

  final MapRepository _repository;

  Future<List<Warehouse>> call(String query) async {
    final warehouses = await _repository.getWarehouses();
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return warehouses;

    return warehouses
        .where(
          (warehouse) =>
              warehouse.name.toLowerCase().contains(trimmed) ||
              warehouse.jobSummary.toLowerCase().contains(trimmed),
        )
        .toList();
  }
}
