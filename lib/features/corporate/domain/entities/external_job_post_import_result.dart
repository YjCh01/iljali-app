import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

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
  final String rawText;
  final double confidence;
  final List<String> warnings;

  bool get hasUsableTitle => title.trim().isNotEmpty;

  JobPostWriteDraft toDraft({
    required WorkerCategory workerCategory,
    String summary = '',
    String? importSourceLabel,
  }) {
    return JobPostWriteDraft(
      title: title,
      workplaceAddress: workplaceAddress,
      jobDescription: jobDescription,
      hourlyWage: hourlyWage ?? const JobPostWriteDraft().hourlyWage,
      workSchedule: workSchedule,
      summary: summary,
      workerCategory: workerCategory,
      importSourceLabel: importSourceLabel,
    );
  }

  ExternalJobPostImportResult copyWith({
    String? title,
    String? workplaceAddress,
    String? workSchedule,
    String? hourlyWage,
    String? jobDescription,
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
      rawText: rawText,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
    );
  }
}
