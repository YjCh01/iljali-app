import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
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

  /// 이력서·근태 그리드용 (간결 표기)
  String get resumeLabel => switch (this) {
        SeekerGender.male => '남',
        SeekerGender.female => '여',
        SeekerGender.other => '-',
        SeekerGender.preferNotToSay => '-',
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
    this.residentIdFront7,
    this.nationality,
    this.preferredRegions = const [],
    this.preferredJobCategories = const [],
    this.workAvailability = const SeekerWorkAvailability(),
    this.profilePhotoRef,
    this.experienceSummary,
    this.resume = const SeekerResumeContent(),
    this.credentialHoldings = const [],
    this.termsAcceptedAt,
    this.termsVersionAccepted,
    this.privacyVersionAccepted,
    this.onboardingCompletedAt,
    this.homeRoadAddress,
    this.homeDetailAddress,
    this.homeLatitude,
    this.homeLongitude,
    this.locationConsentAcceptedAt,
    this.locationConsentVersion,
    this.proposalOffersAccepted = true,
  });

  final bool phoneVerified;
  final DateTime? dateOfBirth;
  final SeekerGender? gender;
  /// 주민등록번호 앞 7자리 (YYMMDD + 구분자리, 예: 900101-1)
  final String? residentIdFront7;
  final SeekerNationality? nationality;
  final List<String> preferredRegions;
  final List<String> preferredJobCategories;
  final SeekerWorkAvailability workAvailability;
  final String? profilePhotoRef;
  final String? experienceSummary;
  final SeekerResumeContent resume;
  final List<SeekerCredentialHolding> credentialHoldings;
  final DateTime? termsAcceptedAt;
  final String? termsVersionAccepted;
  final String? privacyVersionAccepted;
  final DateTime? onboardingCompletedAt;
  /// 실주소 (도로명) — 지도 중심·매칭용
  final String? homeRoadAddress;
  final String? homeDetailAddress;
  final double? homeLatitude;
  final double? homeLongitude;
  final DateTime? locationConsentAcceptedAt;
  final String? locationConsentVersion;
  /// 기업 채용 제안 수신 동의
  final bool proposalOffersAccepted;

  bool get hasHomeAddress =>
      homeRoadAddress != null && homeRoadAddress!.trim().isNotEmpty;

  GeoCoordinate? get homeCoordinate {
    final lat = homeLatitude;
    final lng = homeLongitude;
    if (lat != null && lng != null) return GeoCoordinate(latitude: lat, longitude: lng);
    return null;
  }

  bool get isOnboardingComplete => onboardingCompletedAt != null;

  SeekerMemberProfile copyWith({
    bool? phoneVerified,
    DateTime? dateOfBirth,
    SeekerGender? gender,
    String? residentIdFront7,
    SeekerNationality? nationality,
    List<String>? preferredRegions,
    List<String>? preferredJobCategories,
    SeekerWorkAvailability? workAvailability,
    String? profilePhotoRef,
    String? experienceSummary,
    SeekerResumeContent? resume,
    List<SeekerCredentialHolding>? credentialHoldings,
    DateTime? termsAcceptedAt,
    String? termsVersionAccepted,
    String? privacyVersionAccepted,
    DateTime? onboardingCompletedAt,
    String? homeRoadAddress,
    String? homeDetailAddress,
    double? homeLatitude,
    double? homeLongitude,
    DateTime? locationConsentAcceptedAt,
    String? locationConsentVersion,
    bool? proposalOffersAccepted,
  }) {
    return SeekerMemberProfile(
      phoneVerified: phoneVerified ?? this.phoneVerified,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      residentIdFront7: residentIdFront7 ?? this.residentIdFront7,
      nationality: nationality ?? this.nationality,
      preferredRegions: preferredRegions ?? this.preferredRegions,
      preferredJobCategories:
          preferredJobCategories ?? this.preferredJobCategories,
      workAvailability: workAvailability ?? this.workAvailability,
      profilePhotoRef: profilePhotoRef ?? this.profilePhotoRef,
      experienceSummary: experienceSummary ?? this.experienceSummary,
      resume: resume ?? this.resume,
      credentialHoldings: credentialHoldings ?? this.credentialHoldings,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      termsVersionAccepted: termsVersionAccepted ?? this.termsVersionAccepted,
      privacyVersionAccepted:
          privacyVersionAccepted ?? this.privacyVersionAccepted,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      homeRoadAddress: homeRoadAddress ?? this.homeRoadAddress,
      homeDetailAddress: homeDetailAddress ?? this.homeDetailAddress,
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      locationConsentAcceptedAt:
          locationConsentAcceptedAt ?? this.locationConsentAcceptedAt,
      locationConsentVersion:
          locationConsentVersion ?? this.locationConsentVersion,
      proposalOffersAccepted:
          proposalOffersAccepted ?? this.proposalOffersAccepted,
    );
  }

  Map<String, dynamic> toJson() => {
        'phoneVerified': phoneVerified,
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (gender != null) 'gender': gender!.name,
        if (residentIdFront7 != null) 'residentIdFront7': residentIdFront7,
        if (nationality != null) 'nationality': nationality!.name,
        'preferredRegions': preferredRegions,
        'preferredJobCategories': preferredJobCategories,
        'workAvailability': workAvailability.toJsonList(),
        if (profilePhotoRef != null) 'profilePhotoRef': profilePhotoRef,
        if (experienceSummary != null) 'experienceSummary': experienceSummary,
        'resume': resume.toJson(),
        'credentialHoldings':
            credentialHoldings.map((e) => e.toJson()).toList(),
        if (termsAcceptedAt != null)
          'termsAcceptedAt': termsAcceptedAt!.toIso8601String(),
        if (termsVersionAccepted != null)
          'termsVersionAccepted': termsVersionAccepted,
        if (privacyVersionAccepted != null)
          'privacyVersionAccepted': privacyVersionAccepted,
        if (onboardingCompletedAt != null)
          'onboardingCompletedAt': onboardingCompletedAt!.toIso8601String(),
        if (homeRoadAddress != null) 'homeRoadAddress': homeRoadAddress,
        if (homeDetailAddress != null) 'homeDetailAddress': homeDetailAddress,
        if (homeLatitude != null) 'homeLatitude': homeLatitude,
        if (homeLongitude != null) 'homeLongitude': homeLongitude,
        if (locationConsentAcceptedAt != null)
          'locationConsentAcceptedAt':
              locationConsentAcceptedAt!.toIso8601String(),
        if (locationConsentVersion != null)
          'locationConsentVersion': locationConsentVersion,
        'proposalOffersAccepted': proposalOffersAccepted,
      };

  factory SeekerMemberProfile.fromJson(Map<String, dynamic> json) {
    final legacySummary = json['experienceSummary'] as String?;
    var resume = SeekerResumeContent.fromJson(
      json['resume'] as Map<String, dynamic>?,
    );
    if (resume.selfIntroduction.trim().isEmpty &&
        legacySummary != null &&
        legacySummary.trim().isNotEmpty) {
      resume = resume.copyWith(selfIntroduction: legacySummary.trim());
    }

    return SeekerMemberProfile(
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      gender: _parseGender(json['gender'] as String?),
      residentIdFront7: json['residentIdFront7'] as String?,
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
      workAvailability: SeekerWorkAvailability.fromJsonList(
        json['workAvailability'],
      ),
      profilePhotoRef: json['profilePhotoRef'] as String?,
      experienceSummary: legacySummary,
      resume: resume,
      credentialHoldings: (json['credentialHoldings'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => SeekerCredentialHolding.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList() ??
          const [],
      termsAcceptedAt: json['termsAcceptedAt'] != null
          ? DateTime.tryParse(json['termsAcceptedAt'] as String)
          : null,
      termsVersionAccepted: json['termsVersionAccepted'] as String?,
      privacyVersionAccepted: json['privacyVersionAccepted'] as String?,
      onboardingCompletedAt: json['onboardingCompletedAt'] != null
          ? DateTime.tryParse(json['onboardingCompletedAt'] as String)
          : null,
      homeRoadAddress: json['homeRoadAddress'] as String?,
      homeDetailAddress: json['homeDetailAddress'] as String?,
      homeLatitude: (json['homeLatitude'] as num?)?.toDouble(),
      homeLongitude: (json['homeLongitude'] as num?)?.toDouble(),
      locationConsentAcceptedAt: json['locationConsentAcceptedAt'] != null
          ? DateTime.tryParse(json['locationConsentAcceptedAt'] as String)
          : null,
      locationConsentVersion: json['locationConsentVersion'] as String?,
      proposalOffersAccepted: json['proposalOffersAccepted'] as bool? ?? true,
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
