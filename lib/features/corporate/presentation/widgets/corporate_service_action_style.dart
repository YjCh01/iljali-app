import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 설정·등록 vs 결제 CTA 색상 — 결제는 솔리드 보라, 설정·등록은 연보라
abstract final class CorporateServiceActionStyle {
  static const setupBackground = Color(0xFFF3EEFF);
  static const setupBorder = Color(0xFFD4C4FF);
  static const setupForeground = AppColors.primary;

  static ButtonStyle setupOutlined() => OutlinedButton.styleFrom(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        foregroundColor: setupForeground,
        backgroundColor: setupBackground,
        side: const BorderSide(color: setupBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  static ButtonStyle setupFilled() => FilledButton.styleFrom(
        backgroundColor: setupBackground,
        foregroundColor: setupForeground,
        disabledBackgroundColor: setupBackground.withValues(alpha: 0.55),
        disabledForegroundColor: setupForeground.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  static ButtonStyle paymentFilled() => FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  static BoxDecoration setupCardDecoration({bool configured = false}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: configured ? AppColors.surface : setupBackground,
        border: Border.all(
          color: configured
              ? AppColors.primary.withValues(alpha: 0.4)
              : setupBorder,
        ),
      );
}
