import 'package:flutter/material.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 지도 위 플로팅 컨트롤 — 하단 탭·SafeArea·드래그 시트 여백
abstract final class MapFloatingInsets {
  static const myLocationAboveSearchButton = 56.0;

  /// 구직자 지도 탭 — 하단 네비 위 「이 지역 검색」
  static double searchAreaButtonBottom(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    if (WebLayoutBreakpoints.isWideWeb(context)) return pad + 20;
    return pad + 76;
  }

  /// 기업 홈 등 — 드래그 시트 최소 높이 위 「이 지역 검색」
  static double draggableSheetSearchButtonBottom(
    BuildContext context, {
    double sheetMinFraction = 0.26,
    double gapAboveSheet = 12,
  }) {
    return MediaQuery.sizeOf(context).height * sheetMinFraction + gapAboveSheet;
  }

  /// 드래그 시트가 있는 전체 화면 지도 — 현재 위치 버튼 bottom
  static double myLocationAboveDraggableSheet(
    BuildContext context, {
    double sheetMinFraction = 0.26,
    double gapAboveSheet = 12,
  }) {
    return draggableSheetSearchButtonBottom(
          context,
          sheetMinFraction: sheetMinFraction,
          gapAboveSheet: gapAboveSheet,
        ) +
        myLocationAboveSearchButton;
  }
}
