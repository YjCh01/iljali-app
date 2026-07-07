import 'dart:math' as math;

import 'package:flutter/material.dart';

/// '일자리' 앱 아이콘 — 보라 배경 + 삼태극(보라·민트·노랑)
class IljariIconPainter extends CustomPainter {
  const IljariIconPainter({
    this.backgroundColor = const Color(0xFF7C5CFC),
    this.transparentBackground = false,
    this.useGradientBackground = true,
  });

  final Color backgroundColor;
  final bool transparentBackground;
  final bool useGradientBackground;

  static const Color purple = Color(0xFF7C5CFC);
  static const Color mint = Color(0xFF5EEAD4);
  static const Color yellow = Color(0xFFFFE566);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (!transparentBackground) {
      if (useGradientBackground) {
        final gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2A1B5E), backgroundColor],
        );
        canvas.drawRect(
          rect,
          Paint()..shader = gradient.createShader(rect),
        );
      } else {
        canvas.drawRect(rect, Paint()..color = backgroundColor);
      }
    }

    final scale = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = scale * 0.34;

    _drawSamTaegeuk(canvas, center, outerRadius);
  }

  void _drawSamTaegeuk(Canvas canvas, Offset center, double radius) {
    final smallRadius = radius * 0.5;
    final offset = radius / 3;
    final sqrt3 = math.sqrt(3);

    final lobes = <({Offset smallCenter, Color color})>[
      (smallCenter: Offset(center.dx, center.dy - offset), color: purple),
      (
        smallCenter: Offset(center.dx - sqrt3 * offset, center.dy + offset / 2),
        color: mint,
      ),
      (
        smallCenter: Offset(center.dx + sqrt3 * offset, center.dy + offset / 2),
        color: yellow,
      ),
    ];

    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final paint = Paint()..isAntiAlias = true;

    for (final lobe in lobes) {
      final small = Path()
        ..addOval(
          Rect.fromCircle(center: lobe.smallCenter, radius: smallRadius),
        );
      final shape = Path.combine(PathOperation.intersect, outer, small);
      paint.color = lobe.color;
      canvas.drawPath(shape, paint);
    }
  }

  @override
  bool shouldRepaint(covariant IljariIconPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.transparentBackground != transparentBackground ||
        oldDelegate.useGradientBackground != useGradientBackground;
  }
}

/// 앱 아이콘 미리보기 위젯
class IljariAppIcon extends StatelessWidget {
  const IljariAppIcon({
    super.key,
    this.size = 120,
    this.backgroundColor = const Color(0xFF7C5CFC),
    this.borderRadius,
  });

  final double size;
  final Color backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: IljariIconPainter(backgroundColor: backgroundColor),
    );

    if (borderRadius == null) return icon;

    return ClipRRect(
      borderRadius: borderRadius!,
      child: icon,
    );
  }
}
