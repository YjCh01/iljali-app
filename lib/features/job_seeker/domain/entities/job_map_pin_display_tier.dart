import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 지도 공고 핀 — 일반(회색) · 100회 팩(노란)
enum JobMapPinDisplayTier {
  /// 기본 무료 공고
  standard,

  /// 100회 팩 구매 · 채용협력사
  premiumPartner,
}

extension JobMapPinDisplayTierX on JobMapPinDisplayTier {
  int get sortOrder => index;

  static JobMapPinDisplayTier maxOf(
    JobMapPinDisplayTier a,
    JobMapPinDisplayTier b,
  ) =>
      a.sortOrder >= b.sortOrder ? a : b;

  String get label => switch (this) {
        JobMapPinDisplayTier.standard => '일반',
        JobMapPinDisplayTier.premiumPartner => '100회 팩',
      };

  Color get pinColor => switch (this) {
        JobMapPinDisplayTier.standard => AppColors.textSecondary,
        JobMapPinDisplayTier.premiumPartner => const Color(0xFFFFB800),
      };

  Color get pinLightColor => switch (this) {
        JobMapPinDisplayTier.standard => const Color(0xFFBDBDBD),
        JobMapPinDisplayTier.premiumPartner => const Color(0xFFFFE082),
      };

  Color get pinBorderColor => switch (this) {
        JobMapPinDisplayTier.standard => Colors.white,
        JobMapPinDisplayTier.premiumPartner => const Color(0xFFFFF8E1),
      };

  double get markerSize => switch (this) {
        JobMapPinDisplayTier.standard => 36,
        JobMapPinDisplayTier.premiumPartner => 48,
      };

  double get borderWidth => switch (this) {
        JobMapPinDisplayTier.standard => 2,
        JobMapPinDisplayTier.premiumPartner => 3,
      };

  String get shapeGlyph => switch (this) {
        JobMapPinDisplayTier.standard => '●',
        JobMapPinDisplayTier.premiumPartner => '◆',
      };
}

/// 공고·기업 정보로 지도 핀 등급 결정
abstract final class MapPinTierResolver {
  static JobMapPinDisplayTier resolve({required CorporateJobPost post}) {
    if (post.mapPinDisplayTier != null) return post.mapPinDisplayTier!;
    return resolveFromProfile(registeredBy: post.registeredBy);
  }

  static JobMapPinDisplayTier resolveFromProfile({
    CorporateMemberProfile? registeredBy,
  }) {
    if (registeredBy != null && registeredBy.qualifiesForPremiumMapPin) {
      return JobMapPinDisplayTier.premiumPartner;
    }
    return JobMapPinDisplayTier.standard;
  }

  static JobMapPinDisplayTier resolveForNewPost({
    required CorporateMemberProfile? registeredBy,
  }) =>
      resolveFromProfile(registeredBy: registeredBy);
}

extension CorporateMemberProfileMapPinX on CorporateMemberProfile {
  /// 지속적 채용협력 (아웃소싱·레거시 구독 등)
  bool get isRecruitmentPartner =>
      isEnterpriseOutsourcingEdition || hasLegacyPaidSubscription;

  /// 100회 팩 구매 또는 채용협력사 → 노란 프리미엄 핀
  bool get qualifiesForPremiumMapPin =>
      isRecruitmentPartner ||
      (pushWallet?.qualifiesForPremiumMapPin ?? false);
}
