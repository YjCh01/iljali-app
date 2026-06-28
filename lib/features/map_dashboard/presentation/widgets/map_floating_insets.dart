import 'package:flutter/material.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 지도 위 플로팅 컨트롤 — 하단 탭·SafeArea 여백
abstract final class MapFloatingInsets {
  static double searchAreaButtonBottom(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    if (WebLayoutBreakpoints.isWideWeb(context)) return pad + 20;
    return pad + 76;
  }
}
