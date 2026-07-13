import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// TEMP — 지도 핀 색/모양 검증용 (확인 후 제거)
class PinVisualVerifyPage extends StatelessWidget {
  const PinVisualVerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('핀 색/모양 검증'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '근무지핀 (항상 workplace / 색만 티어)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 24,
            children: [
              for (final tier in [
                JobMapPinDisplayTier.standard,
                JobMapPinDisplayTier.premiumWage,
                JobMapPinDisplayTier.packageActive,
                JobMapPinDisplayTier.closedGhost,
              ])
                _PinCell(
                  label: tier.label,
                  child: JobTeardropPinWidget(
                    bodyColor: tier.pinColor,
                    style: MapPinStyle.workplace,
                    scale: 2.2,
                    ringColor: tier == JobMapPinDisplayTier.packageActive
                        ? MapPinColors.ringTint(tier.pinColor)
                        : null,
                    ringWidth:
                        tier == JobMapPinDisplayTier.packageActive ? 3 : 0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 36),
          const Text(
            '일자리 알림핀 (notification + packagePurple)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const _PinCell(
            label: '알림',
            child: JobTeardropPinWidget(
              bodyColor: MapPinColors.packagePurple,
              style: MapPinStyle.notification,
              scale: 2.2,
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            '정류장 표시핀 (busStop + packagePurple)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const _PinCell(
            label: '정류장',
            child: BusStopPinWidget(
              bodyColor: MapPinColors.packagePurple,
              scale: 2.2,
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            '정류장 연결선 + 방향 화살표 (20px)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const _ShuttleRoutePreview(),
        ],
      ),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _ShuttleRoutePreview extends StatelessWidget {
  const _ShuttleRoutePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: CustomPaint(
        painter: _ShuttleRoutePainter(arrowSize: 20),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ShuttleRoutePainter extends CustomPainter {
  _ShuttleRoutePainter({required this.arrowSize});

  final double arrowSize;

  @override
  void paint(Canvas canvas, Size size) {
    const color = MapPinColors.packagePurple;
    final stops = <Offset>[
      Offset(size.width * 0.18, size.height * 0.62),
      Offset(size.width * 0.42, size.height * 0.38),
      Offset(size.width * 0.68, size.height * 0.55),
      Offset(size.width * 0.86, size.height * 0.28),
    ];

    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < stops.length - 1; i++) {
      _drawDashed(canvas, stops[i], stops[i + 1], outlinePaint, 14, 10);
      _drawDashed(canvas, stops[i], stops[i + 1], dashPaint, 14, 10);
    }

    const pinSize = Size(
      TeardropMapPinArt.busWidth * 1.7,
      TeardropMapPinArt.busHeight * 1.7,
    );
    for (final stop in stops) {
      canvas.save();
      canvas.translate(stop.dx - pinSize.width / 2, stop.dy - pinSize.height);
      TeardropMapPinArt.paintPin(
        canvas,
        pinSize,
        style: MapPinStyle.busStop,
        color: color,
      );
      canvas.restore();
    }

    // 화살표는 핀 위에 그려서 크기 변경이 바로 보이게 함
    for (var i = 0; i < stops.length - 1; i++) {
      _drawArrow(canvas, stops[i], stops[i + 1], color, arrowSize);
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double size,
  ) {
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx) + math.pi / 2;
    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -size * 0.42)
      ..lineTo(size * 0.32, size * 0.28)
      ..lineTo(-size * 0.32, size * 0.28)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  void _drawDashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
    double gap,
  ) {
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    var t = 0.0;
    var draw = true;
    while (t < total) {
      final span = draw ? dash : gap;
      final next = (t + span).clamp(0.0, total);
      if (draw) {
        canvas.drawLine(a + dir * t, a + dir * next, paint);
      }
      t = next;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant _ShuttleRoutePainter oldDelegate) =>
      oldDelegate.arrowSize != arrowSize;
}
