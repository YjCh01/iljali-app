import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

class GetCorporateJobPostsUseCase {
  const GetCorporateJobPostsUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<List<CorporateJobPost>> call() => _dataSource.fetchJobPosts();
}
