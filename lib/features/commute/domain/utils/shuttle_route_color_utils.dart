import 'package:flutter/material.dart';

/// 셔틀 노선 색상 — hex ↔ RGB 변환 및 프리셋
abstract final class ShuttleRouteColorUtils {
  static const presetHexes = [
    '#E53935',
    '#FFFFFF',
    '#1E88E5',
    '#43A047',
    '#FB8C00',
    '#8E24AA',
    '#FDD835',
    '#212121',
    '#78909C',
    '#00838F',
    '#D81B60',
    '#6D4C41',
  ];

  static Color parseHex(String hex) {
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return const Color(0xFFE53935);
    return Color(int.parse(value, radix: 16));
  }

  static String toHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static ({int r, int g, int b}) rgbFromHex(String hex) {
    final argb = parseHex(hex).toARGB32();
    return (
      r: (argb >> 16) & 0xFF,
      g: (argb >> 8) & 0xFF,
      b: argb & 0xFF,
    );
  }

  static String hexFromRgb(int r, int g, int b) {
    return toHex(Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)));
  }

  static bool isValidHex(String input) {
    final normalized = input.trim().replaceFirst('#', '');
    if (normalized.length != 6) return false;
    return int.tryParse(normalized, radix: 16) != null;
  }
}
