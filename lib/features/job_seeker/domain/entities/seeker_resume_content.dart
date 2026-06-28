import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';

/// 학력 항목
class SeekerEducationEntry {
  const SeekerEducationEntry({
    required this.id,
    required this.level,
    required this.graduationStatus,
    this.schoolName,
    this.major,
    this.startYear,
    this.endYear,
  });

  final String id;
  final String level;
  final String graduationStatus;
  final String? schoolName;
  final String? major;
  final int? startYear;
  final int? endYear;

  String get summaryLine {
    final school = (schoolName?.trim().isNotEmpty ?? false)
        ? schoolName!.trim()
        : level;
    return '$level $graduationStatus · $school';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'graduationStatus': graduationStatus,
        if (schoolName != null) 'schoolName': schoolName,
        if (major != null) 'major': major,
        if (startYear != null) 'startYear': startYear,
        if (endYear != null) 'endYear': endYear,
      };

  factory SeekerEducationEntry.fromJson(Map<String, dynamic> json) {
    return SeekerEducationEntry(
      id: json['id'] as String? ?? '',
      level: json['level'] as String? ?? '',
      graduationStatus: json['graduationStatus'] as String? ?? '',
      schoolName: json['schoolName'] as String?,
      major: json['major'] as String?,
      startYear: json['startYear'] as int?,
      endYear: json['endYear'] as int?,
    );
  }

  SeekerEducationEntry copyWith({
    String? level,
    String? graduationStatus,
    String? schoolName,
    String? major,
    int? startYear,
    int? endYear,
  }) {
    return SeekerEducationEntry(
      id: id,
      level: level ?? this.level,
      graduationStatus: graduationStatus ?? this.graduationStatus,
      schoolName: schoolName ?? this.schoolName,
      major: major ?? this.major,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
    );
  }
}

/// 경력 항목
class SeekerExperienceEntry {
  const SeekerExperienceEntry({
    required this.id,
    required this.employmentType,
    required this.companyName,
    required this.jobRole,
    this.startYear,
    this.endYear,
    this.startMonth,
    this.endMonth,
    this.description,
  });

  final String id;
  final String employmentType;
  final String companyName;
  final String jobRole;
  final int? startYear;
  final int? endYear;
  final int? startMonth;
  final int? endMonth;
  final String? description;

  String get summaryLine => '$companyName · $jobRole';

  String? get periodLabel {
    String? part(int? year, int? month) {
      if (year == null) return null;
      if (month != null) return '$year.$month';
      return '$year';
    }

    final start = part(startYear, startMonth);
    final end = part(endYear, endMonth);
    if (start != null && end != null) return '$start — $end';
    return start ?? end;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employmentType': employmentType,
        'companyName': companyName,
        'jobRole': jobRole,
        if (startYear != null) 'startYear': startYear,
        if (endYear != null) 'endYear': endYear,
        if (startMonth != null) 'startMonth': startMonth,
        if (endMonth != null) 'endMonth': endMonth,
        if (description != null) 'description': description,
      };

  factory SeekerExperienceEntry.fromJson(Map<String, dynamic> json) {
    return SeekerExperienceEntry(
      id: json['id'] as String? ?? '',
      employmentType: json['employmentType'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      jobRole: json['jobRole'] as String? ?? '',
      startYear: json['startYear'] as int?,
      endYear: json['endYear'] as int?,
      startMonth: json['startMonth'] as int?,
      endMonth: json['endMonth'] as int?,
      description: json['description'] as String?,
    );
  }
}

/// 면허 항목
class SeekerLicenseEntry {
  const SeekerLicenseEntry({
    required this.id,
    required this.name,
    this.issuer,
    this.acquiredLabel,
  });

  final String id;
  final String name;
  final String? issuer;
  final String? acquiredLabel;

  String get summaryLine => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (issuer != null) 'issuer': issuer,
        if (acquiredLabel != null) 'acquiredLabel': acquiredLabel,
      };

  factory SeekerLicenseEntry.fromJson(Map<String, dynamic> json) {
    return SeekerLicenseEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      issuer: json['issuer'] as String?,
      acquiredLabel: json['acquiredLabel'] as String?,
    );
  }
}

/// 자격증 항목
class SeekerCertificationEntry {
  const SeekerCertificationEntry({
    required this.id,
    required this.name,
    this.issuer,
    this.acquiredLabel,
  });

  final String id;
  final String name;
  final String? issuer;
  final String? acquiredLabel;

  String get summaryLine => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (issuer != null) 'issuer': issuer,
        if (acquiredLabel != null) 'acquiredLabel': acquiredLabel,
      };

  factory SeekerCertificationEntry.fromJson(Map<String, dynamic> json) {
    return SeekerCertificationEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      issuer: json['issuer'] as String?,
      acquiredLabel: json['acquiredLabel'] as String?,
    );
  }
}

/// 이력서 본문 (학력·경력·면허·자격증·자기소개)
class SeekerResumeContent {
  const SeekerResumeContent({
    this.educations = const [],
    this.experiences = const [],
    this.licenses = const [],
    this.certifications = const [],
    this.selfIntroduction = '',
  });

  final List<SeekerEducationEntry> educations;
  final List<SeekerExperienceEntry> experiences;
  final List<SeekerLicenseEntry> licenses;
  final List<SeekerCertificationEntry> certifications;
  final String selfIntroduction;

  bool hasContentFor(ResumeItemKind kind) => switch (kind) {
        ResumeItemKind.education => educations.isNotEmpty,
        ResumeItemKind.experience => experiences.isNotEmpty,
        ResumeItemKind.license => licenses.isNotEmpty,
        ResumeItemKind.certification => certifications.isNotEmpty,
        ResumeItemKind.selfIntroduction =>
          selfIntroduction.trim().isNotEmpty,
      };

  int countFor(ResumeItemKind kind) => switch (kind) {
        ResumeItemKind.education => educations.length,
        ResumeItemKind.experience => experiences.length,
        ResumeItemKind.license => licenses.length,
        ResumeItemKind.certification => certifications.length,
        ResumeItemKind.selfIntroduction =>
          selfIntroduction.trim().isEmpty ? 0 : 1,
      };

  SeekerResumeContent copyWith({
    List<SeekerEducationEntry>? educations,
    List<SeekerExperienceEntry>? experiences,
    List<SeekerLicenseEntry>? licenses,
    List<SeekerCertificationEntry>? certifications,
    String? selfIntroduction,
  }) {
    return SeekerResumeContent(
      educations: educations ?? this.educations,
      experiences: experiences ?? this.experiences,
      licenses: licenses ?? this.licenses,
      certifications: certifications ?? this.certifications,
      selfIntroduction: selfIntroduction ?? this.selfIntroduction,
    );
  }

  Map<String, dynamic> toJson() => {
        'educations': educations.map((e) => e.toJson()).toList(),
        'experiences': experiences.map((e) => e.toJson()).toList(),
        'licenses': licenses.map((e) => e.toJson()).toList(),
        'certifications': certifications.map((e) => e.toJson()).toList(),
        'selfIntroduction': selfIntroduction,
      };

  factory SeekerResumeContent.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SeekerResumeContent();
    List<T> mapList<T>(
      String key,
      T Function(Map<String, dynamic>) from,
    ) {
      final raw = json[key] as List<dynamic>? ?? [];
      return raw
          .whereType<Map>()
          .map((e) => from(Map<String, dynamic>.from(e)))
          .toList();
    }

    return SeekerResumeContent(
      educations: mapList('educations', SeekerEducationEntry.fromJson),
      experiences: mapList('experiences', SeekerExperienceEntry.fromJson),
      licenses: mapList('licenses', SeekerLicenseEntry.fromJson),
      certifications:
          mapList('certifications', SeekerCertificationEntry.fromJson),
      selfIntroduction: json['selfIntroduction'] as String? ?? '',
    );
  }

  /// 공개 동의된 항목만 포함한 복사본
  SeekerResumeContent filtered(Set<ResumeItemKind> disclosed) {
    return SeekerResumeContent(
      educations: disclosed.contains(ResumeItemKind.education)
          ? educations
          : const [],
      experiences: disclosed.contains(ResumeItemKind.experience)
          ? experiences
          : const [],
      licenses:
          disclosed.contains(ResumeItemKind.license) ? licenses : const [],
      certifications: disclosed.contains(ResumeItemKind.certification)
          ? certifications
          : const [],
      selfIntroduction: disclosed.contains(ResumeItemKind.selfIntroduction)
          ? selfIntroduction
          : '',
    );
  }
}

/// 이력서 입력 옵션 (동네알바 스타일)
abstract final class SeekerResumeOptions {
  static const educationLevels = [
    '고등학교',
    '대학교(2년제)',
    '대학교(4년제)',
    '대학원',
    '검정고시',
    '기타',
  ];

  static const graduationStatuses = [
    '졸업',
    '재학',
    '휴학',
    '중퇴',
    '수료',
  ];

  static const employmentTypes = [
    '아르바이트',
    '계약직',
    '정규직',
    '인턴',
    '프리랜서',
    '기타',
  ];

  static List<int> yearOptions({int past = 50}) {
    final now = DateTime.now().year;
    return List.generate(past + 6, (i) => now + 5 - i);
  }

  static const monthOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
}
