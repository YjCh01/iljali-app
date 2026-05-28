import 'package:map/features/corporate/data/datasources/corporate_attendance_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';

class GetCorporateAttendanceUseCase {
  const GetCorporateAttendanceUseCase(this._dataSource);

  final CorporateAttendanceLocalDataSource _dataSource;

  Future<List<CorporateAttendanceRecord>> call() => _dataSource.fetchRecords();
}
