import 'package:map/features/corporate/data/datasources/corporate_applicant_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';

class GetCorporateApplicantsUseCase {
  const GetCorporateApplicantsUseCase(this._dataSource);

  final CorporateApplicantLocalDataSource _dataSource;

  Future<List<CorporateApplicant>> call() => _dataSource.fetchApplicants();
}
