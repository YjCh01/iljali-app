import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 넓은 웹 — 본문을 중앙 고정 폭으로 두고 좌·우에 광고·여백 슬롯 확보
class WebCenteredSiteFrame extends StatelessWidget {
  const WebCenteredSiteFrame({
    super.key,
    required this.child,
    this.maxWidth = WebLayoutBreakpoints.siteFrameMaxWidth,
    this.minSideGutter = WebLayoutBreakpoints.minSideGutter,
    this.sideGutterColor = WebLayoutBreakpoints.sideGutterColor,
    this.leftGutter,
    this.rightGutter,
  });

  final Widget child;
  final double maxWidth;
  final double minSideGutter;
  final Color sideGutterColor;
  final Widget? leftGutter;
  final Widget? rightGutter;

  static bool appliesTo(BuildContext context) =>
      kIsWeb && WebLayoutBreakpoints.isWideWeb(context);

  @override
  Widget build(BuildContext context) {
    if (!appliesTo(context)) return child;

    final media = MediaQuery.of(context);
    final viewport = media.size;
    final layout = _resolveLayout(viewport.width);

    return ColoredBox(
      color: sideGutterColor,
      child: SizedBox(
        width: viewport.width,
        height: viewport.height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: layout.gutterWidth,
              child: leftGutter ?? const SizedBox.shrink(),
            ),
            SizedBox(
              width: layout.frameWidth,
              child: MediaQuery(
                data: media.copyWith(
                  size: Size(layout.frameWidth, viewport.height),
                ),
                child: child,
              ),
            ),
            SizedBox(
              width: layout.gutterWidth,
              child: rightGutter ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  ({double frameWidth, double gutterWidth}) _resolveLayout(double viewportWidth) {
    final sideSpace = viewportWidth - maxWidth;
    if (sideSpace >= minSideGutter * 2) {
      return (frameWidth: maxWidth, gutterWidth: sideSpace / 2);
    }

    final gutterWidth = math.max(
      minSideGutter,
      math.max(0.0, (viewportWidth - maxWidth) / 2),
    );
    final frameWidth = math.max(320.0, viewportWidth - gutterWidth * 2);
    return (frameWidth: frameWidth, gutterWidth: gutterWidth);
  }
}
