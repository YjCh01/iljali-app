import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/work_category/data/repositories/seeker_work_achievement_repository.dart';
import 'package:map/features/work_category/domain/entities/seeker_work_achievement.dart';
import 'package:map/features/work_category/domain/services/work_category_classifier_service.dart';

/// 근무 완료(상호 출근 확인) 시 업무 업적 부여
class WorkAchievementService {
  WorkAchievementService({
    SeekerWorkAchievementRepository? repository,
    CorporateJobPostLocalDataSource? jobPostSource,
  })  : _repositoryFuture = repository != null
            ? Future.value(repository)
            : SeekerWorkAchievementRepository.create(),
        _jobPostSource = jobPostSource ??
            const CorporateJobPostLocalDataSourceImpl();

  final Future<SeekerWorkAchievementRepository> _repositoryFuture;
  final CorporateJobPostLocalDataSource _jobPostSource;

  Future<SeekerWorkAchievementEntry?> tryAwardForApplication(
    HiringApplication application,
  ) async {
    if (!application.isMutuallyConfirmed) return null;

    final repo = await _repositoryFuture;
    final already = await repo.hasAwardedApplication(
      seekerEmail: application.seekerEmail,
      applicationId: application.id,
    );
    if (already) return null;

    final post = await _jobPostSource.findById(application.postId);
    final categoryId = WorkCategoryClassifierService.resolveCategoryId(
      selectedId: post?.workCategoryId,
      title: post?.title ?? application.postTitle,
      jobDescription: post?.jobDescription ?? '',
      summary: post?.summary ?? '',
    );

    return repo.awardOnce(
      seekerEmail: application.seekerEmail,
      applicationId: application.id,
      categoryId: categoryId,
    );
  }

  Future<SeekerWorkAchievementSummary> loadSummary(String seekerEmail) async {
    final repo = await _repositoryFuture;
    return repo.loadSummary(seekerEmail);
  }
}
