import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

/// 기업회원 하위 담당자 프로필 (4자리 담당자 코드 + 검증·플랜)
class CorporateMemberProfile {
  const CorporateMemberProfile({
    required this.companyName,
    required this.businessRegistrationNumber,
    required this.department,
    required this.contactPersonName,
    required this.handlerCode,
    this.entityType = BusinessEntityType.corporation,
    this.verificationStatus = BusinessVerificationStatus.pending,
    this.partnershipTier = PremiumPartnershipTier.basic,
    this.monthlySubscriptionActive = false,
    this.requiresAdminReview = false,
    this.adminReviewApproved = false,
    this.adminReviewReason,
    this.policyAcceptedAt,
    this.certificateImageRef,
    this.industryName,
    this.isSuspended = false,
    this.subscriptionExpiresAt,
    this.isEnterpriseOutsourcingEdition = false,
    this.pushWallet,
    this.businessHeadOfficeAddress,
    this.businessHeadOfficeLatitude,
    this.businessHeadOfficeLongitude,
    this.commuteRouteId,
  });

  final String companyName;
  final String businessRegistrationNumber;
  final String department;
  final String contactPersonName;
  final String handlerCode;
  final BusinessEntityType entityType;
  final BusinessVerificationStatus verificationStatus;
  final PremiumPartnershipTier partnershipTier;
  final bool monthlySubscriptionActive;
  final bool requiresAdminReview;
  final bool adminReviewApproved;
  final String? adminReviewReason;
  final DateTime? policyAcceptedAt;
  final String? certificateImageRef;
  final String? industryName;
  final bool isSuspended;
  final DateTime? subscriptionExpiresAt;
  final bool isEnterpriseOutsourcingEdition;
  final EmployerPushWallet? pushWallet;
  final String? businessHeadOfficeAddress;
  final double? businessHeadOfficeLatitude;
  final double? businessHeadOfficeLongitude;
  final String? commuteRouteId;

  GeoCoordinate? get businessHeadOfficeCoordinate {
    final lat = businessHeadOfficeLatitude;
    final lng = businessHeadOfficeLongitude;
    if (lat == null || lng == null) return null;
    return GeoCoordinate(latitude: lat, longitude: lng);
  }

  String get companyKey =>
      businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');

  String get displayLabel => '$department · $contactPersonName ($handlerCode)';

  bool get isEnterpriseOutsourcing => isEnterpriseOutsourcingEdition;

  bool get hasActivePaidSubscription => false;

  /// @deprecated Legacy — migration only
  bool get hasLegacyPaidSubscription {
    if (!monthlySubscriptionActive) return false;
    if (partnershipTier == PremiumPartnershipTier.basic) return false;
    final expires = subscriptionExpiresAt;
    if (expires == null) return true;
    return expires.isAfter(DateTime.now());
  }

  bool get canUseContactFeatures {
    if (isSuspended) return false;
    if (verificationStatus == BusinessVerificationStatus.suspended ||
        verificationStatus == BusinessVerificationStatus.rejected) {
      return false;
    }
    if (requiresAdminReview && !adminReviewApproved) return false;
    return true;
  }

  CorporateMemberProfile copyWith({
    BusinessEntityType? entityType,
    BusinessVerificationStatus? verificationStatus,
    PremiumPartnershipTier? partnershipTier,
    bool? monthlySubscriptionActive,
    bool? requiresAdminReview,
    bool? adminReviewApproved,
    String? adminReviewReason,
    DateTime? policyAcceptedAt,
    String? certificateImageRef,
    String? industryName,
    bool? isSuspended,
    DateTime? subscriptionExpiresAt,
    bool clearSubscriptionExpiresAt = false,
    bool? isEnterpriseOutsourcingEdition,
    EmployerPushWallet? pushWallet,
    String? businessHeadOfficeAddress,
    double? businessHeadOfficeLatitude,
    double? businessHeadOfficeLongitude,
    String? commuteRouteId,
  }) {
    return CorporateMemberProfile(
      companyName: companyName,
      businessRegistrationNumber: businessRegistrationNumber,
      department: department,
      contactPersonName: contactPersonName,
      handlerCode: handlerCode,
      entityType: entityType ?? this.entityType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      partnershipTier: partnershipTier ?? this.partnershipTier,
      monthlySubscriptionActive:
          monthlySubscriptionActive ?? this.monthlySubscriptionActive,
      requiresAdminReview: requiresAdminReview ?? this.requiresAdminReview,
      adminReviewApproved: adminReviewApproved ?? this.adminReviewApproved,
      adminReviewReason: adminReviewReason ?? this.adminReviewReason,
      policyAcceptedAt: policyAcceptedAt ?? this.policyAcceptedAt,
      certificateImageRef: certificateImageRef ?? this.certificateImageRef,
      industryName: industryName ?? this.industryName,
      isSuspended: isSuspended ?? this.isSuspended,
      subscriptionExpiresAt: clearSubscriptionExpiresAt
          ? null
          : (subscriptionExpiresAt ?? this.subscriptionExpiresAt),
      isEnterpriseOutsourcingEdition:
          isEnterpriseOutsourcingEdition ?? this.isEnterpriseOutsourcingEdition,
      pushWallet: pushWallet ?? this.pushWallet,
      businessHeadOfficeAddress:
          businessHeadOfficeAddress ?? this.businessHeadOfficeAddress,
      businessHeadOfficeLatitude:
          businessHeadOfficeLatitude ?? this.businessHeadOfficeLatitude,
      businessHeadOfficeLongitude:
          businessHeadOfficeLongitude ?? this.businessHeadOfficeLongitude,
      commuteRouteId: commuteRouteId ?? this.commuteRouteId,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'businessRegistrationNumber': businessRegistrationNumber,
        'department': department,
        'contactPersonName': contactPersonName,
        'handlerCode': handlerCode,
        'entityType': entityType.name,
        'verificationStatus': verificationStatus.name,
        'partnershipTier': partnershipTier.name,
        'monthlySubscriptionActive': monthlySubscriptionActive,
        'requiresAdminReview': requiresAdminReview,
        'adminReviewApproved': adminReviewApproved,
        'adminReviewReason': adminReviewReason,
        'policyAcceptedAt': policyAcceptedAt?.toIso8601String(),
        'certificateImageRef': certificateImageRef,
        'industryName': industryName,
        'isSuspended': isSuspended,
        'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
        'isEnterpriseOutsourcingEdition': isEnterpriseOutsourcingEdition,
        if (pushWallet != null) 'pushWallet': pushWallet!.toJson(),
        if (businessHeadOfficeAddress != null)
          'businessHeadOfficeAddress': businessHeadOfficeAddress,
        if (businessHeadOfficeLatitude != null)
          'businessHeadOfficeLatitude': businessHeadOfficeLatitude,
        if (businessHeadOfficeLongitude != null)
          'businessHeadOfficeLongitude': businessHeadOfficeLongitude,
        if (commuteRouteId != null) 'commuteRouteId': commuteRouteId,
      };

  factory CorporateMemberProfile.fromJson(Map<String, dynamic> map) {
    return CorporateMemberProfile(
      companyName: map['companyName'] as String? ?? '',
      businessRegistrationNumber:
          map['businessRegistrationNumber'] as String? ?? '',
      department: map['department'] as String? ?? '',
      contactPersonName: map['contactPersonName'] as String? ?? '',
      handlerCode: map['handlerCode'] as String? ?? '',
      entityType: _parseEntityType(map['entityType'] as String?),
      verificationStatus:
          _parseVerification(map['verificationStatus'] as String?),
      partnershipTier: _parseTier(map['partnershipTier'] as String?),
      monthlySubscriptionActive:
          map['monthlySubscriptionActive'] as bool? ?? false,
      requiresAdminReview: map['requiresAdminReview'] as bool? ?? false,
      adminReviewApproved: map['adminReviewApproved'] as bool? ?? false,
      adminReviewReason: map['adminReviewReason'] as String?,
      policyAcceptedAt:
          DateTime.tryParse(map['policyAcceptedAt'] as String? ?? ''),
      certificateImageRef: map['certificateImageRef'] as String?,
      industryName: map['industryName'] as String?,
      isSuspended: map['isSuspended'] as bool? ?? false,
      subscriptionExpiresAt:
          DateTime.tryParse(map['subscriptionExpiresAt'] as String? ?? ''),
      isEnterpriseOutsourcingEdition:
          map['isEnterpriseOutsourcingEdition'] as bool? ?? false,
      pushWallet: map['pushWallet'] != null
          ? EmployerPushWallet.fromJson(
              Map<String, dynamic>.from(map['pushWallet'] as Map),
            )
          : null,
      businessHeadOfficeAddress: map['businessHeadOfficeAddress'] as String?,
      businessHeadOfficeLatitude:
          (map['businessHeadOfficeLatitude'] as num?)?.toDouble(),
      businessHeadOfficeLongitude:
          (map['businessHeadOfficeLongitude'] as num?)?.toDouble(),
      commuteRouteId: map['commuteRouteId'] as String?,
    );
  }

  static BusinessEntityType _parseEntityType(String? raw) {
    if (raw == null) return BusinessEntityType.corporation;
    try {
      return BusinessEntityType.values.byName(raw);
    } on ArgumentError {
      return BusinessEntityType.corporation;
    }
  }

  static BusinessVerificationStatus _parseVerification(String? raw) {
    if (raw == null) return BusinessVerificationStatus.pending;
    try {
      return BusinessVerificationStatus.values.byName(raw);
    } on ArgumentError {
      return BusinessVerificationStatus.pending;
    }
  }

  static PremiumPartnershipTier _parseTier(String? raw) {
    if (raw == null) return PremiumPartnershipTier.basic;
    try {
      return PremiumPartnershipTier.values.byName(raw);
    } on ArgumentError {
      return PremiumPartnershipTier.basic;
    }
  }
}
