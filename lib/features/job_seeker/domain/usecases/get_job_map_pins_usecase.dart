import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

class GetJobMapPinsUseCase {
  const GetJobMapPinsUseCase(this._dataSource);

  final JobMapPinsDataSource _dataSource;

  Future<List<JobMapPin>> call() => _dataSource.fetchActiveJobPins();
}
