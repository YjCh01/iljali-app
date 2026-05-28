import 'package:flutter/material.dart';

/// '일자리' 앱 아이콘 — 보라 배경 + 만세 실루엣 + ●---●---● 별자리
class IljariIconPainter extends CustomPainter {
  const IljariIconPainter({
    this.backgroundColor = const Color(0xFF7C5CFC),
    this.foregroundColor = Colors.white,
    this.transparentBackground = false,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final bool transparentBackground;

  static const double _dotRadius = 0.033;
  static const double _connectorWidth = 0.017;
  static const double _limbWidth = 0.086;
  static const double _headRadius = 0.076;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = transparentBackground ? Colors.transparent : backgroundColor,
    );

    final paint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _limbWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final connectorPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _connectorWidth * scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final shoulderY = center.dy + scale * 0.10;
    final hipY = center.dy + scale * 0.24;
    final leftShoulder = Offset(center.dx - scale * 0.09, shoulderY);
    final rightShoulder = Offset(center.dx + scale * 0.09, shoulderY);
    final leftHand = Offset(center.dx - scale * 0.18, shoulderY - scale * 0.13);
    final rightHand = Offset(center.dx + scale * 0.18, shoulderY - scale * 0.13);
    final leftFoot = Offset(center.dx - scale * 0.09, hipY + scale * 0.17);
    final rightFoot = Offset(center.dx + scale * 0.09, hipY + scale * 0.17);

    canvas.drawLine(leftHand, leftShoulder, strokePaint);
    canvas.drawLine(rightHand, rightShoulder, strokePaint);
    canvas.drawLine(
      Offset(center.dx, shoulderY),
      Offset(center.dx, hipY),
      strokePaint,
    );
    canvas.drawLine(Offset(center.dx, hipY), leftFoot, strokePaint);
    canvas.drawLine(Offset(center.dx, hipY), rightFoot, strokePaint);

    final headCenter = Offset(center.dx, center.dy + scale * 0.02);
    canvas.drawCircle(headCenter, _headRadius * scale, paint);

    final leftDot = Offset(leftHand.dx, headCenter.dy - scale * 0.26);
    final centerDot = Offset(headCenter.dx, headCenter.dy - scale * 0.29);
    final rightDot = Offset(rightHand.dx, headCenter.dy - scale * 0.26);

    canvas.drawLine(leftDot, centerDot, connectorPaint);
    canvas.drawLine(centerDot, rightDot, connectorPaint);

    for (final dot in [leftDot, centerDot, rightDot]) {
      canvas.drawCircle(dot, _dotRadius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant IljariIconPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.transparentBackground != transparentBackground;
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
