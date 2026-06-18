import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 고용 유형 (일반 · 일용직 · 단기알바 · 계약직)
enum WorkerCategory {
  general,
  daily,
  shortTerm,
  contract,
}

WorkerCategory workerCategoryFromEmployment(JobEmploymentType type) =>
    type == JobEmploymentType.permanent
        ? WorkerCategory.contract
        : WorkerCategory.daily;

WorkerCategory? workerCategoryFromRoleId(String id) => switch (id) {
      'worker_general' => WorkerCategory.general,
      'worker_daily' => WorkerCategory.daily,
      'worker_short_term' => WorkerCategory.shortTerm,
      'worker_contract' => WorkerCategory.contract,
      _ => null,
    };

extension WorkerCategoryX on WorkerCategory {
  String get label => switch (this) {
        WorkerCategory.general => '일반',
        WorkerCategory.daily => '일용직',
        WorkerCategory.shortTerm => '단기알바',
        WorkerCategory.contract => '계약직',
      };

  JobEmploymentType get employmentType => switch (this) {
        WorkerCategory.contract => JobEmploymentType.permanent,
        _ => JobEmploymentType.daily,
      };

  /// 달력에서 근무일을 하루씩 고르는 모드 (일용직 전용)
  bool get usesDailyPickSchedule => this == WorkerCategory.daily;

  /// 급여지급일을 날짜 하나로 지정 (일용직 전용)
  bool get usesAbsolutePaymentDate => this == WorkerCategory.daily;

  /// 급여지급일 달력 선택 + 협의 (단기알바)
  bool get usesCalendarPaymentDate => this == WorkerCategory.shortTerm;
}
