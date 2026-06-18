import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

/// PUSH·노출 UI 색상 — 기본(회색) · 패키지(연보라) · 100회(골드)
enum PushCreditVisualTier {
  basic,
  package,
  premium100,
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
    if (_isPremium100(wallet)) return premium100;
    if (wallet.packageCredits > 0 || wallet.locationSlotsFromPackages > 0) {
      return package;
    }
    return basic;
  }

  /// 지원자 모집하기 — 다음 차감될 일자리 알림핀 기준
  static PushCreditVisualTheme fromNextPushConsume(EmployerPushWallet? wallet) {
    if (wallet == null) return basic;
    if (wallet.packageCredits > 0) {
      return _isPremium100(wallet) ? premium100 : package;
    }
    return basic;
  }

  static bool _isPremium100(EmployerPushWallet wallet) =>
      wallet.purchased100PackBundle || wallet.lifetimePackagesPurchased >= 100;

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

  static const premium100 = PushCreditVisualTheme._(
    tier: PushCreditVisualTier.premium100,
    accent: Color(0xFFC9A227),
    accentLight: Color(0xFFF0D978),
    mapGridBackground: Color(0xFFFFF8E7),
    fabBackground: Color(0xFFC9A227),
    fabForeground: Colors.white,
    actionBackground: Color(0xFFC9A227),
    actionForeground: Colors.white,
  );

  /// 지원자 모집 — 근무지(0)는 고정·회색, 모집지역은 패키지 보라
  static PushCreditVisualTheme forRecruitPoint(int pointIndex) =>
      pointIndex == 0 ? basic : package;
}
