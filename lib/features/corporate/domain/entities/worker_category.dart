import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 고용 유형 (일반 · 일용직 · 단기알바 · 정규직 · 계약직)
enum WorkerCategory {
  general,
  daily,
  shortTerm,
  regular,
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
      'worker_regular' => WorkerCategory.regular,
      'worker_contract' => WorkerCategory.contract,
      _ => null,
    };

extension WorkerCategoryX on WorkerCategory {
  String get label => switch (this) {
        WorkerCategory.general => '일반',
        WorkerCategory.daily => '일용직',
        WorkerCategory.shortTerm => '단기알바',
        WorkerCategory.regular => '정규직',
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

  /// 근무기간 — 첫 근무 시작일만 (정규직)
  bool get usesFirstStartDateOnly => this == WorkerCategory.regular;

  /// 근무기간 — 시작일·종료일 모두 필요 (계약직 · 일반 · 단기알바)
  bool get usesWorkPeriodWithEndDate =>
      !usesFirstStartDateOnly && !usesDailyPickSchedule;

  /// 급여지급일 — 당월·익월 N일 (정규직 · 일반 · 계약직)
  bool get usesMonthlyPaymentDate =>
      this == WorkerCategory.regular ||
      this == WorkerCategory.general ||
      this == WorkerCategory.contract;
}
