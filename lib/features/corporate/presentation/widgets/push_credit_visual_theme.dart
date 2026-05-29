import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

/// 푸시·노출 UI 색상 — 기본(회색) · 패키지(연보라) · 100회(골드)
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

  bool get showBasicPassNotice => isBasic;

  /// 공고 노출 범위 설정 등 — 지갑 기준 표시 티어
  static PushCreditVisualTheme fromWallet(EmployerPushWallet? wallet) {
    if (wallet == null) return basic;
    if (_isPremium100(wallet)) return premium100;
    if (wallet.packageCredits > 0 || wallet.locationSlotsFromPackages > 0) {
      return package;
    }
    return basic;
  }

  /// 지원자 모집하기 — 다음 차감될 이용권 기준
  static PushCreditVisualTheme fromNextPushConsume(EmployerPushWallet? wallet) {
    if (wallet == null) return basic;
    if (_dailyFreeRemaining(wallet) > 0) return basic;
    if (_effectiveSignupBonus(wallet) > 0) return basic;
    if (wallet.packageCredits > 0) {
      return _isPremium100(wallet) ? premium100 : package;
    }
    return basic;
  }

  static bool _isPremium100(EmployerPushWallet wallet) =>
      wallet.purchased100PackBundle || wallet.lifetimePackagesPurchased >= 100;

  static int _dailyFreeRemaining(EmployerPushWallet wallet) {
    if (wallet.lastFreePushDayKey == _todayKey()) return 0;
    return 1;
  }

  static int _effectiveSignupBonus(EmployerPushWallet wallet) {
    if (wallet.signupBonusRemaining <= 0) return 0;
    final expires = wallet.signupBonusExpiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) return 0;
    return wallet.signupBonusRemaining;
  }

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

/// 근무지 무료 푸시(1km · 일 1회) 안내
class BasicPassNoticeBanner extends StatelessWidget {
  const BasicPassNoticeBanner({
    super.key,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  static const noticeText =
      '근무지 무료 푸시(1km · 일 1회)는 근무지 주변에서만 사용할 수 있습니다. '
      '추가 모집지역은 지역 푸시권이 필요합니다.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor ??
            AppColors.primaryLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor ??
              AppColors.primaryLight.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: iconColor ?? AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              noticeText,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
