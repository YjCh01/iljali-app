import 'package:flutter/material.dart';

/// Premium 구독 SME + 전문 기능직 워커 타겟 — **미리보기 전용** 토큰.
/// 프로덕션 `AppTheme`과 분리; `PremiumThemePreviewPage`에서만 사용.
abstract final class PremiumColors {
  static const primary = Color(0xFF5B4FE8);
  static const accent = Color(0xFFF59E0B);
  static const backgroundLight = Color(0xFFFAFAFA);
  static const backgroundDark = Color(0xFF09090B);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF18181B);
  static const textPrimaryLight = Color(0xFF09090B);
  static const textSecondaryLight = Color(0xFF71717A);
  static const textPrimaryDark = Color(0xFFFAFAFA);
  static const textSecondaryDark = Color(0xFFA1A1AA);
  static const borderLight = Color(0xFFE4E4E7);
  static const borderDark = Color(0xFF27272A);
}

abstract final class PremiumTheme {
  static const duration = Duration(milliseconds: 300);
  static const curve = Curves.easeOut;

  static ThemeData forBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? PremiumColors.backgroundDark : PremiumColors.backgroundLight;
    final surface = dark ? PremiumColors.surfaceDark : PremiumColors.surfaceLight;
    final onBg = dark ? PremiumColors.textPrimaryDark : PremiumColors.textPrimaryLight;
    final muted = dark ? PremiumColors.textSecondaryDark : PremiumColors.textSecondaryLight;
    final border = dark ? PremiumColors.borderDark : PremiumColors.borderLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: PremiumColors.primary,
        onPrimary: Colors.white,
        secondary: PremiumColors.accent,
        onSecondary: PremiumColors.backgroundDark,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: surface,
        onSurface: onBg,
      ),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onBg,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.15,
          color: onBg,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: onBg,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onBg,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: onBg),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: muted),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onBg,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: _PremiumPageTransitionBuilder(),
          TargetPlatform.android: _PremiumPageTransitionBuilder(),
          TargetPlatform.macOS: _PremiumPageTransitionBuilder(),
        },
      ),
    );
  }
}

class _PremiumPageTransitionBuilder extends PageTransitionsBuilder {
  const _PremiumPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: PremiumTheme.curve,
      reverseCurve: PremiumTheme.curve.flipped,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
