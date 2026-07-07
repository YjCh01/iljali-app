import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

/// 외부 공고 파싱 결과
class ExternalJobPostImportResult {
  const ExternalJobPostImportResult({
    required this.platform,
    this.sourceUrl,
    this.title = '',
    this.workplaceAddress,
    this.workSchedule = '',
    this.hourlyWage,
    this.jobDescription = '',
    this.descriptionBody = const JobPostDescriptionBody(),
    this.rawText = '',
    this.confidence = 0.5,
    this.warnings = const [],
  });

  final ExternalJobPostPlatform platform;
  final String? sourceUrl;
  final String title;
  final String? workplaceAddress;
  final String workSchedule;
  final String? hourlyWage;
  final String jobDescription;
  final JobPostDescriptionBody descriptionBody;
  final String rawText;
  final double confidence;
  final List<String> warnings;

  bool get hasUsableTitle => title.trim().isNotEmpty;

  /// 텍스트에서 고용 형태 추정
  WorkerCategory inferWorkerCategory() {
    final blob = '$title $jobDescription $rawText'.toLowerCase();
    if (blob.contains('일용') || blob.contains('당일')) {
      return WorkerCategory.daily;
    }
    if (blob.contains('단기')) return WorkerCategory.shortTerm;
    if (blob.contains('정규') || blob.contains('상시')) {
      return WorkerCategory.regular;
    }
    if (blob.contains('계약')) return WorkerCategory.contract;
    if (hourlyWage != null &&
        (hourlyWage!.contains('일급') || hourlyWage!.contains('일당'))) {
      return WorkerCategory.daily;
    }
    return WorkerCategory.shortTerm;
  }

  bool _needsScheduleNegotiable(WorkerCategory workerCategory) {
    final schedule = workSchedule.trim();
    if (schedule.isEmpty) return true;
    final spec = WorkScheduleCodec.tryParse(schedule);
    if (spec == null) return true;
    return !spec.isCompleteFor(
      workPeriodNegotiable: workerCategory.usesFirstStartDateOnly,
    );
  }

  JobPostWriteDraft toDraft({
    required WorkerCategory workerCategory,
    String summary = '',
    String? importSourceLabel,
    DateTime? paymentDate,
    bool? workScheduleNegotiable,
  }) {
    final negotiable =
        workScheduleNegotiable ?? _needsScheduleNegotiable(workerCategory);
    return JobPostWriteDraft(
      title: title,
      workplaceAddress: workplaceAddress,
      jobDescription: jobDescription,
      hourlyWage: hourlyWage ?? const JobPostWriteDraft().hourlyWage,
      workSchedule: negotiable && workSchedule.trim().isEmpty
          ? ''
          : workSchedule,
      summary: summary,
      workerCategory: workerCategory,
      paymentDate: paymentDate,
      importSourceLabel: importSourceLabel,
      workScheduleNegotiable: negotiable,
      descriptionBody: descriptionBody,
    );
  }

  ExternalJobPostImportResult copyWith({
    String? title,
    String? workplaceAddress,
    String? workSchedule,
    String? hourlyWage,
    String? jobDescription,
    JobPostDescriptionBody? descriptionBody,
    double? confidence,
    List<String>? warnings,
  }) {
    return ExternalJobPostImportResult(
      platform: platform,
      sourceUrl: sourceUrl,
      title: title ?? this.title,
      workplaceAddress: workplaceAddress ?? this.workplaceAddress,
      workSchedule: workSchedule ?? this.workSchedule,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      jobDescription: jobDescription ?? this.jobDescription,
      descriptionBody: descriptionBody ?? this.descriptionBody,
      rawText: rawText,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
    );
  }
}
