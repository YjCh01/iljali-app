import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';

/// 외부 이력서(알바몬·잡코리아 등) AI 불러오기 결과
class SeekerResumeImportResult {
  const SeekerResumeImportResult({
    required this.resume,
    required this.rawText,
    required this.platform,
    required this.source,
    required this.confidence,
    required this.message,
    this.warnings = const [],
  });

  final SeekerResumeContent resume;
  final String rawText;
  final String platform;
  final String source;
  final double confidence;
  final String message;
  final List<String> warnings;

  bool get hasStructuredContent =>
      resume.educations.isNotEmpty ||
      resume.experiences.isNotEmpty ||
      resume.licenses.isNotEmpty ||
      resume.certifications.isNotEmpty ||
      resume.selfIntroduction.trim().isNotEmpty;

  factory SeekerResumeImportResult.fromRemote(Map<String, dynamic> json) {
    final warnings = <String>[];
    final message = (json['message'] as String?)?.trim() ?? '';
    if (message.isNotEmpty) warnings.add(message);

    return SeekerResumeImportResult(
      resume: SeekerResumeContent.fromJson({
        'educations': json['educations'],
        'experiences': json['experiences'],
        'licenses': json['licenses'],
        'certifications': json['certifications'],
        'selfIntroduction': json['selfIntroduction'] ?? '',
      }),
      rawText: json['raw_text'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      source: json['source'] as String? ?? 'remote',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      message: message,
      warnings: warnings,
    );
  }

  SeekerResumeImportResult copyWith({
    SeekerResumeContent? resume,
    List<String>? warnings,
  }) {
    return SeekerResumeImportResult(
      resume: resume ?? this.resume,
      rawText: rawText,
      platform: platform,
      source: source,
      confidence: confidence,
      message: message,
      warnings: warnings ?? this.warnings,
    );
  }
}

enum SeekerResumeImportPlatform {
  albamon,
  jobkorea,
  saramin,
  incruit,
  unknown;

  static SeekerResumeImportPlatform detectFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('albamon')) return SeekerResumeImportPlatform.albamon;
    if (lower.contains('jobkorea')) return SeekerResumeImportPlatform.jobkorea;
    if (lower.contains('saramin')) return SeekerResumeImportPlatform.saramin;
    if (lower.contains('incruit')) return SeekerResumeImportPlatform.incruit;
    return SeekerResumeImportPlatform.unknown;
  }

  String get label => switch (this) {
        SeekerResumeImportPlatform.albamon => '알바몬',
        SeekerResumeImportPlatform.jobkorea => '잡코리아',
        SeekerResumeImportPlatform.saramin => '사람인',
        SeekerResumeImportPlatform.incruit => '인크루트',
        SeekerResumeImportPlatform.unknown => '기타',
      };
}
