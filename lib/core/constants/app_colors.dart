import 'package:flutter/material.dart';

/// 앱 전역 색상 상수
abstract final class AppColors {
  static const Color primary = Color(0xFF7C5CFC);
  static const Color primaryLight = Color(0xFFB8A4FF);
  static const Color background = Color(0xFFF7F7F7);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color searchBarBackground = Colors.white;
  static const Color searchBarBorder = Color(0xFFE0E0E0);

  /// Auth — 짙은 퍼플 테마
  static const Color authBackground = Color(0xFF2A1B5E);
  static const Color authBackgroundDeep = Color(0xFF1E1245);
  static const Color authCard = Colors.white;
  static const Color authButtonDark = Color(0xFF1A1A1A);

  /// BASIC 등 무료 플랜 — 현재 이용 중 뱃지
  static const Color activeBasicBadgeBg = Color(0xFFD8FF4A);
  static const Color activeBasicBadgeText = Color(0xFF2A4D0E);
}
