import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 지도 + 설정 패널 — 모바일: 위·아래 / 넓은 웹: 좌(지도)·우(패널)
class MapFormSplitLayout extends StatelessWidget {
  const MapFormSplitLayout({
    super.key,
    required this.map,
    required this.panel,
    this.panelWidth = 480,
    this.mobileMapHeight,
  });

  final Widget map;
  final Widget panel;
  final double panelWidth;

  /// 모바일에서 지도 높이. null이면 화면 비율로 자동 계산.
  final double? mobileMapHeight;

  static double resolveMobileMapHeight(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + kToolbarHeight;
    final bodyHeight = media.size.height - topInset;
    return math
        .min(constraints.maxWidth, math.min(bodyHeight * 0.42, 400))
        .clamp(220.0, 400.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (WebLayoutBreakpoints.isWideWeb(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: map,
              ),
            ),
          ),
          Material(
            color: AppColors.surface,
            child: Container(
              width: panelWidth,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  left: BorderSide(
                    color: AppColors.primaryLight.withValues(alpha: 0.35),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: panel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final height = mobileMapHeight ??
                resolveMobileMapHeight(context, constraints);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: height,
                child: map,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: panel,
          ),
        ),
      ],
    );
  }
}

/// 지도 위 + 목록·버튼 아래 — [MapFormSplitLayout]과 동일한 wide 분기
class MapStackSplitLayout extends StatelessWidget {
  const MapStackSplitLayout({
    super.key,
    required this.map,
    required this.bottom,
    this.panelWidth = 480,
    this.topBanner,
  });

  final Widget map;
  final Widget bottom;
  final double panelWidth;
  final Widget? topBanner;

  @override
  Widget build(BuildContext context) {
    if (WebLayoutBreakpoints.isWideWeb(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBanner != null) topBanner!,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: map,
                    ),
                  ),
                ),
                Material(
                  color: AppColors.surface,
                  child: Container(
                    width: panelWidth,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppColors.primaryLight.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: bottom),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topBanner != null) topBanner!,
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: map,
            ),
          ),
        ),
        Expanded(flex: 5, child: bottom),
      ],
    );
  }
}
