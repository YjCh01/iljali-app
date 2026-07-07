import 'package:flutter/material.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/utils/premium_wage_pin_policy.dart';

/// 지도 공고 핀 — 활성(파랑) · 마감유령(회색). 등급별 색상은 추후 기업 설정.
enum JobMapPinDisplayTier {
  /// 기본 무료 공고
  standard,

  /// 시급 ≥ 최저임금+1,000원 — 하늘색 핀
  premiumWage,

  /// 일자리 알림핀 구매·보유 — 보라 핀
  packageActive,

  /// 마감유령핀 — 만료·마감된 무료 공고 / 어드민 배치
  closedGhost,
}

extension JobMapPinDisplayTierX on JobMapPinDisplayTier {
  int get sortOrder => index;

  static JobMapPinDisplayTier maxOf(
    JobMapPinDisplayTier a,
    JobMapPinDisplayTier b,
  ) =>
      a.sortOrder >= b.sortOrder ? a : b;

  /// 레거시 황금핀 등 저장값 → 보라 핀
  static JobMapPinDisplayTier? tryParseLegacy(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'premiumPartner') return JobMapPinDisplayTier.packageActive;
    try {
      return JobMapPinDisplayTier.values.byName(raw);
    } catch (_) {
      return null;
    }
  }

  String get label => switch (this) {
        JobMapPinDisplayTier.standard => '일반',
        JobMapPinDisplayTier.premiumWage => '고시급',
        JobMapPinDisplayTier.packageActive => '유료',
        JobMapPinDisplayTier.closedGhost => '마감유령',
      };

  Color get pinColor => switch (this) {
        JobMapPinDisplayTier.closedGhost => MapPinColors.ghost,
        _ => MapPinColors.active,
      };

  Color get pinLightColor => switch (this) {
        JobMapPinDisplayTier.closedGhost => const Color(0xFFE0E0E0),
        _ => MapPinColors.active.withValues(alpha: 0.55),
      };

  Color get pinBorderColor => switch (this) {
        JobMapPinDisplayTier.closedGhost => const Color(0xFFEEEEEE),
        _ => MapPinColors.active,
      };

  double get markerSize => switch (this) {
        JobMapPinDisplayTier.standard => 36,
        JobMapPinDisplayTier.premiumWage => 38,
        JobMapPinDisplayTier.packageActive => 42,
        JobMapPinDisplayTier.closedGhost => 34,
      };

  double get borderWidth => switch (this) {
        JobMapPinDisplayTier.standard => 2,
        JobMapPinDisplayTier.premiumWage => 2,
        JobMapPinDisplayTier.packageActive => 2.5,
        JobMapPinDisplayTier.closedGhost => 2,
      };

  String get shapeGlyph => switch (this) {
        JobMapPinDisplayTier.closedGhost => '×',
        _ => '●',
      };
}

/// 공고·기업 정보로 지도 핀 등급 결정
abstract final class MapPinTierResolver {
  static JobMapPinDisplayTier resolve({required CorporateJobPost post}) {
    final profileTier = post.mapPinDisplayTier ??
        resolveFromProfile(registeredBy: post.registeredBy);
    final wageTier = resolveWageTier(
      hourlyWage: post.hourlyWage,
      workSchedule: post.workSchedule,
    );
    return JobMapPinDisplayTierX.maxOf(profileTier, wageTier);
  }

  static JobMapPinDisplayTier resolveFromProfile({
    CorporateMemberProfile? registeredBy,
  }) {
    if (registeredBy != null && registeredBy.qualifiesForPackageMapPin) {
      return JobMapPinDisplayTier.packageActive;
    }
    return JobMapPinDisplayTier.standard;
  }

  /// 시급·일급 등 — 최저+1,000원(×근무시간) 이상이면 premiumWage
  static JobMapPinDisplayTier resolveWageTier({
    required String hourlyWage,
    String workSchedule = '',
  }) {
    if (PremiumWagePinPolicy.qualifiesFromWageLabel(
      wageLabel: hourlyWage,
      workSchedule: workSchedule,
    )) {
      return JobMapPinDisplayTier.premiumWage;
    }
    return JobMapPinDisplayTier.standard;
  }

  static JobMapPinDisplayTier resolveForNewPost({
    required CorporateMemberProfile? registeredBy,
    String? hourlyWage,
    String workSchedule = '',
  }) {
    final profileTier = resolveFromProfile(registeredBy: registeredBy);
    if (hourlyWage == null || hourlyWage.trim().isEmpty) {
      return profileTier;
    }
    return JobMapPinDisplayTierX.maxOf(
      profileTier,
      resolveWageTier(hourlyWage: hourlyWage, workSchedule: workSchedule),
    );
  }
}

extension CorporateMemberProfileMapPinX on CorporateMemberProfile {
  /// 일자리 알림핀 보유 — 보라 핀 (100회 팩 할인만, 핀 색상 혜택 없음)
  bool get qualifiesForPackageMapPin {
    final wallet = pushWallet;
    if (wallet == null) return false;
    return wallet.packageCredits > 0 || wallet.exposurePushBundleCredits > 0;
  }
}
