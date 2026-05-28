import 'package:map/features/corporate/data/datasources/workplace_address_data_source_factory.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_local_data_source.dart';
class SearchWorkplaceAddressUseCase {
  SearchWorkplaceAddressUseCase([WorkplaceAddressDataSource? dataSource])
      : _dataSource = dataSource ?? WorkplaceAddressDataSourceFactory.create();

  final WorkplaceAddressDataSource _dataSource;

  Future<WorkplaceAddressSearchResult> call(String query) =>
      _dataSource.search(query);
}
