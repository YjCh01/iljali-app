import 'package:flutter/material.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 지도 위 플로팅 컨트롤 — 하단 탭·SafeArea·드래그 시트 여백
abstract final class MapFloatingInsets {
  /// 현재 위치(위) · 영역 새로고침(아래) 스택 간격 (44 + 8)
  static const stackedControlGap = 52.0;

  /// @Deprecated — 기존 이름 호환. [stackedControlGap]과 동일.
  static const myLocationAboveSearchButton = stackedControlGap;

  /// 구직자 지도 탭 — 스택 하단(새로고침) 기준
  static double searchAreaButtonBottom(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    if (WebLayoutBreakpoints.isWideWeb(context)) return pad + 20;
    return pad + 76;
  }

  /// 구직자 — 현재 위치 버튼 (새로고침 위)
  static double myLocationAboveSearchArea(BuildContext context) =>
      searchAreaButtonBottom(context) + stackedControlGap;

  /// 기업 홈 등 — 드래그 시트 위 스택 하단(새로고침)
  static double draggableSheetSearchButtonBottom(
    BuildContext context, {
    double sheetMinFraction = 0.26,
    double gapAboveSheet = 12,
  }) {
    return MediaQuery.sizeOf(context).height * sheetMinFraction + gapAboveSheet;
  }

  /// 드래그 시트 지도 — 현재 위치 버튼 (새로고침 위)
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
        stackedControlGap;
  }

  /// 핀 콜아웃이 열릴 때 핀을 둘 화면 Y 비율 (0=상단, 0.5=중앙).
  /// 콜아웃이 핀 **위**에 뜨므로 핀은 중하단으로 내린다.
  static const calloutPinScreenY = 0.62;

  /// 콜아웃 상단 오프셋 — 배너·앱바 아래, 핀보다 위.
  static double pinCalloutTop(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).top;
    // 프로모 배너(~40) + 여유
    return pad + 56;
  }

  /// @Deprecated — 하단 앵커 대신 [pinCalloutTop] 사용
  static double pinCalloutAboveSheet(
    BuildContext context, {
    required double sheetFraction,
    double gapAboveSheet = 8,
  }) {
    return pinCalloutBottomInset(
      screenHeight: MediaQuery.sizeOf(context).height,
      sheetFraction: sheetFraction,
      gapAboveSheet: gapAboveSheet,
    );
  }

  /// 순수 계산 — 테스트용.
  static double pinCalloutBottomInset({
    required double screenHeight,
    required double sheetFraction,
    double gapAboveSheet = 8,
  }) {
    if (screenHeight <= 0) return gapAboveSheet;
    final fraction = sheetFraction.clamp(0.12, 0.85);
    return screenHeight * fraction + gapAboveSheet;
  }
}
