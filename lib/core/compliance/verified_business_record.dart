import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';

/// OCR + 국세청 검증 결과 (MVP — 로컬 저장)
class VerifiedBusinessRecord {
  const VerifiedBusinessRecord({
    required this.businessRegistrationNumber,
    required this.companyName,
    required this.entityType,
    required this.status,
    required this.verifiedAt,
    this.industryName,
    this.representativeName,
    this.certificateImageRef,
    this.registeredBusinessAddress,
    this.ocrConfidence,
    this.ntsApiMatched = false,
    this.requiresAdminReview = false,
    this.adminReviewReason,
    this.trustScore = 100,
  });

  final String businessRegistrationNumber;
  final String companyName;
  final BusinessEntityType entityType;
  final BusinessVerificationStatus status;
  final DateTime verifiedAt;
  final String? industryName;
  final String? representativeName;
  final String? certificateImageRef;
  /// 등록증·국세청 등록 사업장 소재지 (OCR 또는 내정보)
  final String? registeredBusinessAddress;
  final double? ocrConfidence;
  final bool ntsApiMatched;
  final bool requiresAdminReview;
  final String? adminReviewReason;
  final int trustScore;

  VerifiedBusinessRecord copyWith({
    BusinessVerificationStatus? status,
    bool? requiresAdminReview,
    String? adminReviewReason,
    int? trustScore,
    String? registeredBusinessAddress,
    String? certificateImageRef,
  }) {
    return VerifiedBusinessRecord(
      businessRegistrationNumber: businessRegistrationNumber,
      companyName: companyName,
      entityType: entityType,
      status: status ?? this.status,
      verifiedAt: verifiedAt,
      industryName: industryName,
      representativeName: representativeName,
      certificateImageRef: certificateImageRef ?? this.certificateImageRef,
      registeredBusinessAddress:
          registeredBusinessAddress ?? this.registeredBusinessAddress,
      ocrConfidence: ocrConfidence,
      ntsApiMatched: ntsApiMatched,
      requiresAdminReview: requiresAdminReview ?? this.requiresAdminReview,
      adminReviewReason: adminReviewReason ?? this.adminReviewReason,
      trustScore: trustScore ?? this.trustScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessRegistrationNumber': businessRegistrationNumber,
        'companyName': companyName,
        'entityType': entityType.name,
        'status': status.name,
        'verifiedAt': verifiedAt.toIso8601String(),
        'industryName': industryName,
        'representativeName': representativeName,
        'certificateImageRef': certificateImageRef,
        'registeredBusinessAddress': registeredBusinessAddress,
        'ocrConfidence': ocrConfidence,
        'ntsApiMatched': ntsApiMatched,
        'requiresAdminReview': requiresAdminReview,
        'adminReviewReason': adminReviewReason,
        'trustScore': trustScore,
      };

  factory VerifiedBusinessRecord.fromJson(Map<String, dynamic> json) {
    return VerifiedBusinessRecord(
      businessRegistrationNumber:
          json['businessRegistrationNumber'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      entityType: BusinessEntityType.values.byName(
        json['entityType'] as String? ?? BusinessEntityType.corporation.name,
      ),
      status: BusinessVerificationStatus.values.byName(
        json['status'] as String? ?? BusinessVerificationStatus.pending.name,
      ),
      verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? '') ??
          DateTime.now(),
      industryName: json['industryName'] as String?,
      representativeName: json['representativeName'] as String?,
      certificateImageRef: json['certificateImageRef'] as String?,
      registeredBusinessAddress: json['registeredBusinessAddress'] as String?,
      ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble(),
      ntsApiMatched: json['ntsApiMatched'] as bool? ?? false,
      requiresAdminReview: json['requiresAdminReview'] as bool? ?? false,
      adminReviewReason: json['adminReviewReason'] as String?,
      trustScore: json['trustScore'] as int? ?? 100,
    );
  }
}
