import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/listings/data/repositories/listing_repository_impl.dart';
import 'package:map/features/listings/domain/usecases/create_listing_usecase.dart';
import 'package:map/features/map_dashboard/data/repositories/map_repository_impl.dart';
import 'package:map/features/map_dashboard/domain/usecases/search_warehouses_usecase.dart';

void main() {
  group('SearchWarehousesUseCase', () {
    final useCase = SearchWarehousesUseCase(MapRepositoryImpl());

    test('returns empty list for empty query when no warehouses', () async {
      final results = await useCase('');
      expect(results, isEmpty);
    });

    test('returns empty list when no warehouses match query', () async {
      final results = await useCase('강남');
      expect(results, isEmpty);
    });
  });

  group('CreateListingUseCase', () {
    test('rejects empty title', () async {
      final useCase = CreateListingUseCase(ListingRepositoryImpl());
      final result = await useCase(
        title: '',
        description: '설명',
        warehouseName: '강남 지점',
        hourlyWage: '12000',
      );
      expect(result.isSuccess, isFalse);
    });

    test('creates listing with valid input', () async {
      final useCase = CreateListingUseCase(ListingRepositoryImpl());
      final result = await useCase(
        title: '분류 알바',
        description: '초보 가능',
        warehouseName: '강남 지점',
        hourlyWage: '12500',
      );
      expect(result.isSuccess, isTrue);
    });
  });
}
