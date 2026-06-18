import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';

/// 포토샵 스타일 — 원형 색상환 팝업
Future<String?> showShuttleCircleColorPickerDialog(
  BuildContext context, {
  required String initialHex,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _CircleColorPickerDialog(initialHex: initialHex),
  );
}

/// 포토샵 스타일 — 블록형(SV 사각형 + 색조 슬라이더) 팝업
Future<String?> showShuttleBlockColorPickerDialog(
  BuildContext context, {
  required String initialHex,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _BlockColorPickerDialog(initialHex: initialHex),
  );
}

class _CircleColorPickerDialog extends StatefulWidget {
  const _CircleColorPickerDialog({required this.initialHex});

  final String initialHex;

  @override
  State<_CircleColorPickerDialog> createState() =>
      _CircleColorPickerDialogState();
}

class _CircleColorPickerDialogState extends State<_CircleColorPickerDialog> {
  static const _size = 280.0;
  static const _outerR = 128.0;
  static const _innerR = 92.0;

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(ShuttleRouteColorUtils.parseHex(widget.initialHex));
  }

  Color get _color => _hsv.toColor();

  void _applyFromLocal(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    final delta = local - center;
    final dist = delta.distance;
    final angle = math.atan2(delta.dy, delta.dx);
    final hue = (angle * 180 / math.pi + 360) % 360;

    final sq = _svSquareRect();
    if (sq.contains(local)) {
      final s = ((local.dx - sq.left) / sq.width).clamp(0.0, 1.0);
      final v = (1 - (local.dy - sq.top) / sq.height).clamp(0.0, 1.0);
      setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
      return;
    }

    if (dist >= _innerR - 4 && dist <= _outerR + 8) {
      setState(() => _hsv = _hsv.withHue(hue));
    }
  }

  Rect _svSquareRect() {
    const side = _innerR * 1.45;
    return Rect.fromCenter(
      center: const Offset(_size / 2, _size / 2),
      width: side,
      height: side,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sq = _svSquareRect();
    final svMarker = Offset(
      sq.left + _hsv.saturation * sq.width,
      sq.top + (1 - _hsv.value) * sq.height,
    );
    final hueRad = _hsv.hue * math.pi / 180;
    final hueMarker = Offset(
      _size / 2 + math.cos(hueRad) * ((_outerR + _innerR) / 2),
      _size / 2 + math.sin(hueRad) * ((_outerR + _innerR) / 2),
    );

    return AlertDialog(
      title: const Text('원형 색상 선택'),
      content: SizedBox(
        width: _size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '바깥 원에서 색조, 가운데 사각형에서 채도·명도',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onPanDown: (d) => _applyFromLocal(d.localPosition),
              onPanUpdate: (d) => _applyFromLocal(d.localPosition),
              onTapDown: (d) => _applyFromLocal(d.localPosition),
              child: SizedBox(
                width: _size,
                height: _size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: const Size(_size, _size),
                      painter: _HueRingPainter(
                        outerR: _outerR,
                        innerR: _innerR,
                      ),
                    ),
                    Positioned.fromRect(
                      rect: sq,
                      child: CustomPaint(
                        painter: _SvSquarePainter(hue: _hsv.hue),
                      ),
                    ),
                    Positioned(
                      left: hueMarker.dx - 8,
                      top: hueMarker.dy - 8,
                      child: _PickerMarker(borderColor: Colors.white),
                    ),
                    Positioned(
                      left: svMarker.dx - 7,
                      top: svMarker.dy - 7,
                      child: _PickerMarker(
                        borderColor: _hsv.value > 0.55 ? Colors.black54 : Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ColorPreviewRow(color: _color),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ShuttleRouteColorUtils.toHex(_color)),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _BlockColorPickerDialog extends StatefulWidget {
  const _BlockColorPickerDialog({required this.initialHex});

  final String initialHex;

  @override
  State<_BlockColorPickerDialog> createState() => _BlockColorPickerDialogState();
}

class _BlockColorPickerDialogState extends State<_BlockColorPickerDialog> {
  static const _sqSize = 220.0;
  static const _hueW = 28.0;

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(ShuttleRouteColorUtils.parseHex(widget.initialHex));
  }

  Color get _color => _hsv.toColor();

  void _applySv(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - local.dy / size.height).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
  }

  void _applyHue(Offset local, double height) {
    final hue = ((local.dy / height) * 360).clamp(0.0, 359.9);
    setState(() => _hsv = _hsv.withHue(hue));
  }

  @override
  Widget build(BuildContext context) {
    final svMarker = Offset(
      _hsv.saturation * _sqSize,
      (1 - _hsv.value) * _sqSize,
    );
    final hueMarkerY = (_hsv.hue / 360) * _sqSize;

    return AlertDialog(
      title: const Text('블록형 색상 선택'),
      content: SizedBox(
        width: _sqSize + _hueW + 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '사각형에서 채도·명도, 오른쪽 막대에서 색조',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onPanDown: (d) => _applySv(d.localPosition, const Size(_sqSize, _sqSize)),
                  onPanUpdate: (d) => _applySv(d.localPosition, const Size(_sqSize, _sqSize)),
                  onTapDown: (d) => _applySv(d.localPosition, const Size(_sqSize, _sqSize)),
                  child: SizedBox(
                    width: _sqSize,
                    height: _sqSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: const Size(_sqSize, _sqSize),
                          painter: _SvSquarePainter(hue: _hsv.hue),
                        ),
                        Positioned(
                          left: svMarker.dx - 7,
                          top: svMarker.dy - 7,
                          child: _PickerMarker(
                            borderColor:
                                _hsv.value > 0.55 ? Colors.black54 : Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onPanDown: (d) => _applyHue(d.localPosition, _sqSize),
                  onPanUpdate: (d) => _applyHue(d.localPosition, _sqSize),
                  onTapDown: (d) => _applyHue(d.localPosition, _sqSize),
                  child: SizedBox(
                    width: _hueW,
                    height: _sqSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CustomPaint(
                            size: const Size(_hueW, _sqSize),
                            painter: const _HueBarPainter(),
                          ),
                        ),
                        Positioned(
                          left: -2,
                          top: hueMarkerY.clamp(0, _sqSize - 4) - 4,
                          child: Container(
                            width: _hueW + 4,
                            height: 8,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ColorPreviewRow(color: _color),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ShuttleRouteColorUtils.toHex(_color)),
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _ColorPreviewRow extends StatelessWidget {
  const _ColorPreviewRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          ShuttleRouteColorUtils.toHex(color),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PickerMarker extends StatelessWidget {
  const _PickerMarker({
    required this.borderColor,
    this.size = 16,
  });

  final Color borderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 2),
        ],
      ),
    );
  }
}

class _HueRingPainter extends CustomPainter {
  const _HueRingPainter({
    required this.outerR,
    required this.innerR,
  });

  final double outerR;
  final double innerR;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = List.generate(
      360,
      (i) => HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor(),
    )..add(HSVColor.fromAHSV(1, 0, 1, 1).toColor());

    final paint = Paint()
      ..shader = SweepGradient(
        colors: colors,
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: outerR))
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR;

    canvas.drawCircle(center, (outerR + innerR) / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) => false;
}

class _HueBarPainter extends CustomPainter {
  const _HueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final colors = List.generate(
      360,
      (i) => HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor(),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter oldDelegate) => false;
}

class _SvSquarePainter extends CustomPainter {
  const _SvSquarePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final base = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final hPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, base],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, hPaint);

    final vPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vPaint);
  }

  @override
  bool shouldRepaint(covariant _SvSquarePainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}
