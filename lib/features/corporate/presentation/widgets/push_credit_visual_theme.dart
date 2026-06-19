import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

/// PUSH·노출 UI 색상 — 기본(회색) · 패키지(연보라)
enum PushCreditVisualTier {
  basic,
  package,
}

class PushCreditVisualTheme {
  const PushCreditVisualTheme._({
    required this.tier,
    required this.accent,
    required this.accentLight,
    required this.mapGridBackground,
    required this.fabBackground,
    required this.fabForeground,
    required this.actionBackground,
    required this.actionForeground,
  });

  final PushCreditVisualTier tier;
  final Color accent;
  final Color accentLight;
  final Color mapGridBackground;
  final Color fabBackground;
  final Color fabForeground;
  final Color actionBackground;
  final Color actionForeground;

  bool get isBasic => tier == PushCreditVisualTier.basic;

  /// 공고 노출 범위 설정 등 — 지갑 기준 표시 티어
  static PushCreditVisualTheme fromWallet(EmployerPushWallet? wallet) {
    if (wallet == null) return basic;
    if (wallet.packageCredits > 0 || wallet.locationSlotsFromPackages > 0) {
      return package;
    }
    return basic;
  }

  /// 지원자 모집하기 — 다음 차감될 일자리 알림핀 기준
  static PushCreditVisualTheme fromNextPushConsume(EmployerPushWallet? wallet) {
    if (wallet == null) return basic;
    if (wallet.packageCredits > 0) return package;
    return basic;
  }

  static const basic = PushCreditVisualTheme._(
    tier: PushCreditVisualTier.basic,
    accent: Color(0xFF8A8A8A),
    accentLight: Color(0xFFCFCFCF),
    mapGridBackground: Color(0xFFEFEFEF),
    fabBackground: Color(0xFF9E9E9E),
    fabForeground: Colors.white,
    actionBackground: Color(0xFFE8E0FF),
    actionForeground: Color(0xFF7C5CFC),
  );

  static const package = PushCreditVisualTheme._(
    tier: PushCreditVisualTier.package,
    accent: Color(0xFF9B86F0),
    accentLight: Color(0xFFD4CBFB),
    mapGridBackground: Color(0xFFEDE8FF),
    fabBackground: Color(0xFF9B86F0),
    fabForeground: Colors.white,
    actionBackground: Color(0xFF9B86F0),
    actionForeground: Colors.white,
  );

  /// 지원자 모집 — 근무지(0)는 고정·회색, 모집지역은 패키지 보라
  static PushCreditVisualTheme forRecruitPoint(int pointIndex) =>
      pointIndex == 0 ? basic : package;

  static PushCreditVisualTheme withAccent(Color accent) {
    return PushCreditVisualTheme._(
      tier: PushCreditVisualTier.package,
      accent: accent,
      accentLight: Color.lerp(accent, Colors.white, 0.55)!,
      mapGridBackground: Color.lerp(accent, Colors.white, 0.92)!,
      fabBackground: accent,
      fabForeground: Colors.white,
      actionBackground: accent,
      actionForeground: Colors.white,
    );
  }
}
