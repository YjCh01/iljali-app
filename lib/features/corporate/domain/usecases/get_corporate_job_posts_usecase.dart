import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/corporate_job_post_scope.dart';

class GetCorporateJobPostsUseCase {
  const GetCorporateJobPostsUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  /// 로그인 기업회원 소속 공고만 — 타사 공고 제외
  Future<List<CorporateJobPost>> call() async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    if (companyKey == null || companyKey.isEmpty) return const [];
    final all = await _dataSource.fetchJobPosts();
    return CorporateJobPostScope.filterForCompany(all, companyKey);
  }
}
