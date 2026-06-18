import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';

enum SeekerGender {
  male,
  female,
  other,
  preferNotToSay,
}

enum SeekerNationality {
  domestic,
  foreign,
}

extension SeekerGenderX on SeekerGender {
  String get label => switch (this) {
        SeekerGender.male => '남성',
        SeekerGender.female => '여성',
        SeekerGender.other => '기타',
        SeekerGender.preferNotToSay => '응답 안 함',
      };
}

extension SeekerNationalityX on SeekerNationality {
  String get label => switch (this) {
        SeekerNationality.domestic => '내국인',
        SeekerNationality.foreign => '외국인',
      };
}

/// 구직자 회원 프로필 (가입·매칭용)
class SeekerMemberProfile {
  const SeekerMemberProfile({
    required this.phoneVerified,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.preferredRegions = const [],
    this.preferredJobCategories = const [],
    this.workAvailability = const SeekerWorkAvailability(),
    this.profilePhotoRef,
    this.experienceSummary,
    this.termsAcceptedAt,
    this.onboardingCompletedAt,
  });

  final bool phoneVerified;
  final DateTime? dateOfBirth;
  final SeekerGender? gender;
  final SeekerNationality? nationality;
  final List<String> preferredRegions;
  final List<String> preferredJobCategories;
  final SeekerWorkAvailability workAvailability;
  final String? profilePhotoRef;
  final String? experienceSummary;
  final DateTime? termsAcceptedAt;
  final DateTime? onboardingCompletedAt;

  bool get isOnboardingComplete => onboardingCompletedAt != null;

  SeekerMemberProfile copyWith({
    bool? phoneVerified,
    DateTime? dateOfBirth,
    SeekerGender? gender,
    SeekerNationality? nationality,
    List<String>? preferredRegions,
    List<String>? preferredJobCategories,
    SeekerWorkAvailability? workAvailability,
    String? profilePhotoRef,
    String? experienceSummary,
    DateTime? termsAcceptedAt,
    DateTime? onboardingCompletedAt,
  }) {
    return SeekerMemberProfile(
      phoneVerified: phoneVerified ?? this.phoneVerified,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      nationality: nationality ?? this.nationality,
      preferredRegions: preferredRegions ?? this.preferredRegions,
      preferredJobCategories:
          preferredJobCategories ?? this.preferredJobCategories,
      workAvailability: workAvailability ?? this.workAvailability,
      profilePhotoRef: profilePhotoRef ?? this.profilePhotoRef,
      experienceSummary: experienceSummary ?? this.experienceSummary,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'phoneVerified': phoneVerified,
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (gender != null) 'gender': gender!.name,
        if (nationality != null) 'nationality': nationality!.name,
        'preferredRegions': preferredRegions,
        'preferredJobCategories': preferredJobCategories,
        'workAvailability': workAvailability.encode(),
        if (profilePhotoRef != null) 'profilePhotoRef': profilePhotoRef,
        if (experienceSummary != null) 'experienceSummary': experienceSummary,
        if (termsAcceptedAt != null)
          'termsAcceptedAt': termsAcceptedAt!.toIso8601String(),
        if (onboardingCompletedAt != null)
          'onboardingCompletedAt': onboardingCompletedAt!.toIso8601String(),
      };

  factory SeekerMemberProfile.fromJson(Map<String, dynamic> json) {
    return SeekerMemberProfile(
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      gender: _parseGender(json['gender'] as String?),
      nationality: _parseNationality(json['nationality'] as String?),
      preferredRegions: (json['preferredRegions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      preferredJobCategories:
          (json['preferredJobCategories'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      workAvailability: SeekerWorkAvailability.decode(
        json['workAvailability'] as String?,
      ),
      profilePhotoRef: json['profilePhotoRef'] as String?,
      experienceSummary: json['experienceSummary'] as String?,
      termsAcceptedAt: json['termsAcceptedAt'] != null
          ? DateTime.tryParse(json['termsAcceptedAt'] as String)
          : null,
      onboardingCompletedAt: json['onboardingCompletedAt'] != null
          ? DateTime.tryParse(json['onboardingCompletedAt'] as String)
          : null,
    );
  }

  static SeekerGender? _parseGender(String? raw) {
    if (raw == null) return null;
    for (final value in SeekerGender.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  static SeekerNationality? _parseNationality(String? raw) {
    if (raw == null) return null;
    for (final value in SeekerNationality.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// 희망 업무 카테고리 (가입 UI용)
abstract final class SeekerJobCategories {
  static const all = [
    '물류·입출고',
    '식품·공장',
    '포장·피킹',
    '검수·QC',
    '청소·환경',
    '기타',
  ];
}

/// 희망 근무 지역 프리셋
abstract final class SeekerRegionPresets {
  static const all = [
    '서울',
    '경기',
    '인천',
    '부산',
    '대구',
    '광주',
    '대전',
    '울산',
    '세종',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];
}
