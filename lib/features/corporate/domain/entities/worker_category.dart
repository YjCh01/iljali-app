import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 고용 유형 (일반 · 일용직 · 계약직)
enum WorkerCategory {
  general,
  daily,
  contract,
}

WorkerCategory workerCategoryFromEmployment(JobEmploymentType type) =>
    type == JobEmploymentType.permanent
        ? WorkerCategory.contract
        : WorkerCategory.daily;

WorkerCategory? workerCategoryFromRoleId(String id) => switch (id) {
      'worker_general' => WorkerCategory.general,
      'worker_daily' => WorkerCategory.daily,
      'worker_contract' => WorkerCategory.contract,
      _ => null,
    };

extension WorkerCategoryX on WorkerCategory {
  String get label => switch (this) {
        WorkerCategory.general => '일반',
        WorkerCategory.daily => '일용직',
        WorkerCategory.contract => '계약직',
      };

  JobEmploymentType get employmentType => switch (this) {
        WorkerCategory.contract => JobEmploymentType.permanent,
        _ => JobEmploymentType.daily,
      };

}
