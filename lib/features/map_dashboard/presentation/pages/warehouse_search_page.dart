import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/map_dashboard/data/repositories/map_repository_impl.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/domain/usecases/search_warehouses_usecase.dart';

/// 물류센터·일자리 로컬 검색
class WarehouseSearchPage extends StatefulWidget {
  const WarehouseSearchPage({super.key});

  @override
  State<WarehouseSearchPage> createState() => _WarehouseSearchPageState();
}

class _WarehouseSearchPageState extends State<WarehouseSearchPage> {
  final _searchController = TextEditingController();
  final _searchWarehouses = SearchWarehousesUseCase(MapRepositoryImpl());

  List<Warehouse> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _runSearch('');
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    final results = await _searchWarehouses(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _onQueryChanged() => _runSearch(_searchController.text);

  void _selectWarehouse(Warehouse warehouse) {
    Navigator.of(context).pop(warehouse);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('근무지 검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '센터 이름, 일자리 키워드 검색',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.searchBarBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.searchBarBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final warehouse = _results[index];
                          return Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => _selectWarehouse(warehouse),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      warehouse.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      warehouse.jobSummary,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '시급 ${warehouse.hourlyWage}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
