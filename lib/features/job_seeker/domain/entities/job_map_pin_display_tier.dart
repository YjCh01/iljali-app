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

  /// 어드민 이벤트핑 — 퀴즈·투표·안내 (채용보다 낮은 우선순위)
  event,
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
        JobMapPinDisplayTier.event => '이벤트',
      };

  Color get pinColor => switch (this) {
        JobMapPinDisplayTier.standard => MapPinColors.freeGray,
        JobMapPinDisplayTier.premiumWage => MapPinColors.active,
        JobMapPinDisplayTier.packageActive => MapPinColors.packagePurple,
        JobMapPinDisplayTier.closedGhost => const Color(0xFFD1D5DB),
        JobMapPinDisplayTier.event => const Color(0xFFFF6F00),
      };

  Color get pinLightColor => switch (this) {
        JobMapPinDisplayTier.closedGhost => const Color(0xFFE0E0E0),
        _ => pinColor.withValues(alpha: 0.55),
      };

  Color get pinBorderColor => switch (this) {
        JobMapPinDisplayTier.standard => MapPinColors.freeGray,
        JobMapPinDisplayTier.premiumWage => MapPinColors.active,
        JobMapPinDisplayTier.packageActive => MapPinColors.packagePurpleRing,
        JobMapPinDisplayTier.closedGhost => const Color(0xFFEEEEEE),
        JobMapPinDisplayTier.event => const Color(0xFFFFE0B2),
      };

  double get markerSize => switch (this) {
        JobMapPinDisplayTier.standard => 36,
        JobMapPinDisplayTier.premiumWage => 38,
        JobMapPinDisplayTier.packageActive => 42,
        JobMapPinDisplayTier.closedGhost => 34,
        JobMapPinDisplayTier.event => 40,
      };

  double get borderWidth => switch (this) {
        JobMapPinDisplayTier.standard => 2,
        JobMapPinDisplayTier.premiumWage => 2,
        JobMapPinDisplayTier.packageActive => 2.5,
        JobMapPinDisplayTier.closedGhost => 2,
        JobMapPinDisplayTier.event => 2.5,
      };

  String get shapeGlyph => switch (this) {
        JobMapPinDisplayTier.closedGhost => '×',
        JobMapPinDisplayTier.event => '★',
        _ => '●',
      };
}

/// 공고·기업 정보로 지도 핀 등급 결정
///
/// 근무지 핀 색은 시급(회색/하늘)만 반영한다.
/// 알림핀 보유·`packageActive` entitlement는 근무지 색에 섞지 않는다
/// (알림핀은 [JobRecruitmentMapPin] + `pinColorHex`로 따로 그린다).
abstract final class MapPinTierResolver {
  static JobMapPinDisplayTier resolve({required CorporateJobPost post}) {
    if (post.mapPinDisplayTier == JobMapPinDisplayTier.closedGhost) {
      return JobMapPinDisplayTier.closedGhost;
    }
    final wageTier = resolveWageTier(
      hourlyWage: post.hourlyWage,
      workSchedule: post.workSchedule,
    );
    if (post.mapPinDisplayTier == JobMapPinDisplayTier.premiumWage) {
      return JobMapPinDisplayTier.premiumWage;
    }
    // packageActive 등 알림핀 티어는 근무지 색에 적용하지 않음
    return wageTier;
  }

  static JobMapPinDisplayTier resolveFromProfile({
    CorporateMemberProfile? registeredBy,
  }) {
    // 지갑·패키지 보유와 무관 — 근무지는 항상 기본(시급 규칙은 resolve에서 합산)
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
    if (hourlyWage == null || hourlyWage.trim().isEmpty) {
      return resolveFromProfile(registeredBy: registeredBy);
    }
    return resolveWageTier(hourlyWage: hourlyWage, workSchedule: workSchedule);
  }
}

extension CorporateMemberProfileMapPinX on CorporateMemberProfile {
  /// @Deprecated 근무지 색에 더 이상 사용하지 않음 — 알림핀은 별도 마커
  bool get qualifiesForPackageMapPin {
    final wallet = pushWallet;
    if (wallet == null) return false;
    return wallet.packageCredits > 0 || wallet.exposurePushBundleCredits > 0;
  }
}
