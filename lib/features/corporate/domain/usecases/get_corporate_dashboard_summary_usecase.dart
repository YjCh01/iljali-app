import 'package:map/features/corporate/data/datasources/corporate_dashboard_local_data_source.dart';

class GetCorporateDashboardSummaryUseCase {
  const GetCorporateDashboardSummaryUseCase(this._dataSource);

  final CorporateDashboardLocalDataSource _dataSource;

  Future<CorporateDashboardSummary> call() => _dataSource.fetchSummary();
}
