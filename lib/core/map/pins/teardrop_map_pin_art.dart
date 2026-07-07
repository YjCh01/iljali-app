import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 지도 핀 기본 색 — 활성 / 유령·마감
abstract final class MapPinColors {
  static const active = Color(0xFF6BAED6);
  static const ghost = Color(0xFF9E9E9E);
  static const selected = Color(0xFFFF6F00);
}

/// 참고 이미지 3종 — 정류장(사각) · 알림(링 물방울) · 근무지(링 물방울·두꺼운 링)
enum MapPinStyle {
  busStop,
  notification,
  workplace,
}

/// 지도 핀 렌더링 (Canvas + SVG)
abstract final class TeardropMapPinArt {
  static const pinWidth = 38.0;
  static const pinHeight = 50.0;
  static const busWidth = 34.0;
  static const busHeight = 44.0;

  static const jobWidth = pinWidth;
  static const jobHeight = pinHeight;

  static MapPinStyle styleForTier(JobMapPinDisplayTier tier) => switch (tier) {
        JobMapPinDisplayTier.packageActive => MapPinStyle.notification,
        _ => MapPinStyle.workplace,
      };

  static double headRadius(Size size) => size.width * 0.44;

  static Offset tipPoint(Size size) => Offset(size.width / 2, size.height - 1);

  static void paintPin(
    Canvas canvas,
    Size size, {
    required MapPinStyle style,
    required Color color,
    bool selected = false,
    Color selectedRingColor = MapPinColors.selected,
  }) {
    switch (style) {
      case MapPinStyle.busStop:
        _paintBusStop(canvas, size, color: color, selected: selected);
      case MapPinStyle.notification:
        _paintRingTeardrop(
          canvas,
          size,
          color: color,
          holeRatio: 0.36,
          selected: selected,
          selectedRingColor: selectedRingColor,
        );
      case MapPinStyle.workplace:
        _paintRingTeardrop(
          canvas,
          size,
          color: color,
          holeRatio: 0.24,
          selected: selected,
          selectedRingColor: selectedRingColor,
        );
    }
  }

  static void paintJobPin(
    Canvas canvas,
    Size size, {
    required Color bodyColor,
    required Color borderColor,
    required String centerLabel,
    required MapPinStyle style,
    bool selected = false,
    Color selectedRingColor = MapPinColors.selected,
  }) {
    paintPin(
      canvas,
      size,
      style: style,
      color: bodyColor,
      selected: selected,
      selectedRingColor: selectedRingColor,
    );
  }

  static void paintBusStopPin(
    Canvas canvas,
    Size size, {
    required Color bodyColor,
    Color borderColor = Colors.white,
  }) {
    _paintBusStop(canvas, size, color: bodyColor);
  }

  static String pinHtml({
    required MapPinStyle style,
    required String bodyHex,
    required double width,
    required double height,
    bool selected = false,
  }) {
    return switch (style) {
      MapPinStyle.busStop => _busStopHtml(bodyHex, width, height, selected),
      MapPinStyle.notification =>
        _ringTeardropHtml(bodyHex, width, height, 0.36, selected),
      MapPinStyle.workplace =>
        _ringTeardropHtml(bodyHex, width, height, 0.24, selected),
    };
  }

  static String jobPinHtml({
    required String bodyHex,
    required String borderHex,
    required String centerLabel,
    required double width,
    required double height,
    MapPinStyle style = MapPinStyle.workplace,
    bool selected = false,
  }) =>
      pinHtml(
        style: style,
        bodyHex: bodyHex,
        width: width,
        height: height,
        selected: selected,
      );

  static String busStopPinHtml({
    required String bodyHex,
    required String borderHex,
    required double width,
    required double height,
  }) =>
      _busStopHtml(bodyHex, width, height, false);

  static void _paintDropShadow(Canvas canvas, Offset tip, double w) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tip.dx, tip.dy + w * 0.05),
        width: w * 0.36,
        height: w * 0.09,
      ),
      Paint()..color = const Color(0x38000000),
    );
  }

  static Paint _gradientFill(Rect bounds, Color color) {
    final light = Color.lerp(color, Colors.white, 0.32)!;
    final mid = color;
    final dark = Color.lerp(color, Colors.black, 0.22)!;
    return Paint()
      ..shader = ui.Gradient.linear(
        Offset(bounds.left, bounds.top),
        Offset(bounds.right, bounds.bottom),
        [light, mid, dark],
        const [0.0, 0.42, 1.0],
      )
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
  }

  static void _paintBusStop(
    Canvas canvas,
    Size size, {
    required Color color,
    bool selected = false,
  }) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final tip = Offset(cx, h - 1);
    final path = _busStopPath(size);

    _paintDropShadow(canvas, tip, w);

    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = MapPinColors.selected.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..isAntiAlias = true,
      );
    }

    canvas.drawPath(path, _gradientFill(path.getBounds(), color));
  }

  static Path _busStopPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final sqW = w * 0.86;
    final sqH = w * 0.74;
    final top = 1.0;
    final left = cx - sqW / 2;
    final right = cx + sqW / 2;
    final bottom = top + sqH;
    final r = w * 0.12;
    final tipY = h - 1.0;
    final tipHalf = w * 0.11;

    final path = Path()
      ..moveTo(left + r, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(cx + tipHalf, bottom)
      ..lineTo(cx, tipY)
      ..lineTo(cx - tipHalf, bottom)
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r))
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..close();
    return path;
  }

  static void _paintRingTeardrop(
    Canvas canvas,
    Size size, {
    required Color color,
    required double holeRatio,
    bool selected = false,
    Color selectedRingColor = MapPinColors.selected,
  }) {
    final w = size.width;
    final outer = _outerTeardropPath(size);
    final holeR = w * holeRatio;
    final holeC = _holeCenter(size);
    final hole = Path()
      ..addOval(Rect.fromCircle(center: holeC, radius: holeR));
    final ring = Path.combine(PathOperation.difference, outer, hole);
    final tip = tipPoint(size);

    _paintDropShadow(canvas, tip, w);

    if (selected) {
      canvas.drawPath(
        outer,
        Paint()
          ..color = selectedRingColor.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    canvas.drawPath(ring, _gradientFill(ring.getBounds(), color));
  }

  static Path _outerTeardropPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final r = headRadius(size);
    final headCy = r + w * 0.03;
    final tipY = h - 1;

    final path = Path();
    path.moveTo(cx, tipY);
    path.cubicTo(
      w * 0.88,
      h * 0.60,
      w * 0.88,
      headCy + r * 0.12,
      cx + r,
      headCy,
    );
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, headCy), radius: r),
      0,
      -math.pi,
      false,
    );
    path.cubicTo(
      w * 0.12,
      headCy + r * 0.12,
      w * 0.12,
      h * 0.60,
      cx,
      tipY,
    );
    path.close();
    return path;
  }

  static Offset _holeCenter(Size size) {
    final w = size.width;
    final r = headRadius(size);
    return Offset(w / 2, r + w * 0.03);
  }

  static String _gradientDef(String id, String bodyHex) {
    final light = _shiftHex(bodyHex, 0.28);
    final dark = _shiftHex(bodyHex, -0.18);
    return '<linearGradient id="$id" x1="0%" y1="0%" x2="100%" y2="100%">'
        '<stop offset="0%" stop-color="$light"/>'
        '<stop offset="45%" stop-color="$bodyHex"/>'
        '<stop offset="100%" stop-color="$dark"/>'
        '</linearGradient>';
  }

  static String _shadowDef(String id) =>
      '<radialGradient id="$id" cx="50%" cy="50%" r="50%">'
      '<stop offset="0%" stop-color="#00000040"/>'
      '<stop offset="100%" stop-color="#00000000"/>'
      '</radialGradient>';

  static String _busStopHtml(
    String bodyHex,
    double width,
    double height,
    bool selected,
  ) {
    final gid = 'bsg_${bodyHex.hashCode}';
    final sid = 'bss_${bodyHex.hashCode}';
    final cx = width / 2;
    final tipY = height - 1;
    final ring = selected
        ? '<path d="${_svgBusStopPath(width, height)}" fill="none" '
            'stroke="#FF6F0045" stroke-width="3"/>'
        : '';
    return '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" '
        'viewBox="0 0 $width $height" style="display:block;overflow:visible">'
        '<defs>${_gradientDef(gid, bodyHex)}${_shadowDef(sid)}</defs>'
        '<ellipse cx="$cx" cy="${tipY + width * 0.05}" rx="${width * 0.18}" '
        'ry="${width * 0.045}" fill="url(#$sid)"/>'
        '$ring'
        '<path d="${_svgBusStopPath(width, height)}" fill="url(#$gid)"/>'
        '</svg>';
  }

  static String _svgBusStopPath(double w, double h) {
    final cx = w / 2;
    final sqW = w * 0.86;
    final sqH = w * 0.74;
    final top = 1.0;
    final left = cx - sqW / 2;
    final right = cx + sqW / 2;
    final bottom = top + sqH;
    final r = w * 0.12;
    final tipY = h - 1;
    final tipHalf = w * 0.11;
    return 'M ${left + r} $top '
        'L ${right - r} $top '
        'Q $right $top $right ${top + r} '
        'L $right ${bottom - r} '
        'Q $right $bottom ${right - r} $bottom '
        'L ${cx + tipHalf} $bottom '
        'L $cx $tipY '
        'L ${cx - tipHalf} $bottom '
        'L ${left + r} $bottom '
        'Q $left $bottom $left ${bottom - r} '
        'L $left ${top + r} '
        'Q $left $top ${left + r} $top Z';
  }

  static String _ringTeardropHtml(
    String bodyHex,
    double width,
    double height,
    double holeRatio,
    bool selected,
  ) {
    final gid = 'rtg_${bodyHex.hashCode}_$holeRatio';
    final sid = 'rts_${bodyHex.hashCode}';
    final outer = _svgOuterPath(width, height);
    final hc = _holeCenter(Size(width, height));
    final hr = width * holeRatio;
    final cx = width / 2;
    final tipY = height - 1;
    final ring = selected
        ? '<path d="$outer" fill="#FF6F0045" stroke="none"/>'
        : '';
    return '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" '
        'viewBox="0 0 $width $height" style="display:block;overflow:visible">'
        '<defs>${_gradientDef(gid, bodyHex)}${_shadowDef(sid)}</defs>'
        '<ellipse cx="$cx" cy="${tipY + width * 0.05}" rx="${width * 0.18}" '
        'ry="${width * 0.045}" fill="url(#$sid)"/>'
        '$ring'
        '<path fill-rule="evenodd" clip-rule="evenodd" '
        'd="$outer M ${hc.dx} ${hc.dy - hr} A $hr $hr 0 1 0 ${hc.dx} ${hc.dy + hr} '
        'A $hr $hr 0 1 0 ${hc.dx} ${hc.dy - hr} Z" fill="url(#$gid)"/>'
        '</svg>';
  }

  static String _svgOuterPath(double w, double h) {
    final cx = w / 2;
    final r = w * 0.44;
    final headCy = r + w * 0.03;
    final tipY = h - 1;
    return 'M $cx $tipY '
        'C ${w * 0.88} ${h * 0.60} ${w * 0.88} ${headCy + r * 0.12} ${cx + r} $headCy '
        'A $r $r 0 0 0 ${cx - r} $headCy '
        'C ${w * 0.12} ${headCy + r * 0.12} ${w * 0.12} ${h * 0.60} $cx $tipY Z';
  }

  static String _shiftHex(String hex, double amount) {
    var h = hex.replaceFirst('#', '');
    if (h.length != 6) return hex;
    final r = int.parse(h.substring(0, 2), radix: 16);
    final g = int.parse(h.substring(2, 4), radix: 16);
    final b = int.parse(h.substring(4, 6), radix: 16);
    int shift(int c) =>
        (amount > 0 ? c + (255 - c) * amount : c * (1 + amount))
            .round()
            .clamp(0, 255);
    return '#${shift(r).toRadixString(16).padLeft(2, '0')}'
        '${shift(g).toRadixString(16).padLeft(2, '0')}'
        '${shift(b).toRadixString(16).padLeft(2, '0')}';
  }
}

/// Naver Map 네이티브용 핀 비트맵 캐시
abstract final class MapPinOverlayIconCache {
  static final _cache = <String, NOverlayImage>{};

  static Future<NOverlayImage> pin({
    required MapPinStyle style,
    required Color bodyColor,
    bool selected = false,
    double scale = 1,
  }) async {
    final key =
        'pin_v4_${style.name}_${bodyColor.toARGB32()}_${selected}_$scale';
    final cached = _cache[key];
    if (cached != null) return cached;

    final (width, height) = switch (style) {
      MapPinStyle.busStop => (
          TeardropMapPinArt.busWidth * scale,
          TeardropMapPinArt.busHeight * scale,
        ),
      _ => (
          TeardropMapPinArt.pinWidth * scale,
          TeardropMapPinArt.pinHeight * scale,
        ),
    };

    final bytes = await _render((canvas, size) {
      TeardropMapPinArt.paintPin(
        canvas,
        size,
        style: style,
        color: bodyColor,
        selected: selected,
      );
    }, width, height);

    final image = await NOverlayImage.fromByteArray(bytes, cacheKey: key);
    _cache[key] = image;
    return image;
  }

  static Future<NOverlayImage> jobTeardrop({
    required Color bodyColor,
    required Color borderColor,
    required String centerLabel,
    MapPinStyle style = MapPinStyle.workplace,
    bool selected = false,
    double scale = 1,
  }) =>
      pin(style: style, bodyColor: bodyColor, selected: selected, scale: scale);

  static Future<NOverlayImage> busStop({
    required Color bodyColor,
    Color borderColor = Colors.white,
    double scale = 1,
  }) =>
      pin(
        style: MapPinStyle.busStop,
        bodyColor: bodyColor,
        scale: scale,
      );

  /// 유령노선 정류장 — 작은 회색 원 + 번호
  static Future<NOverlayImage> ghostRouteStopDot({
    required int number,
  }) async {
    final key = 'ghost_route_stop_$number';
    final cached = _cache[key];
    if (cached != null) return cached;

    const size = 26.0;
    final bytes = await _render((canvas, canvasSize) {
      final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
      canvas.drawCircle(
        center,
        size / 2 - 1,
        Paint()..color = MapPinColors.ghost,
      );
      canvas.drawCircle(
        center,
        size / 2 - 1,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        center - Offset(text.width / 2, text.height / 2),
      );
    }, size, size);

    final image = await NOverlayImage.fromByteArray(bytes, cacheKey: key);
    _cache[key] = image;
    return image;
  }

  /// 유령노선 근무지 — 작은 회색 사각 점
  static Future<NOverlayImage> ghostRouteWorkplaceDot() async {
    const key = 'ghost_route_workplace';
    final cached = _cache[key];
    if (cached != null) return cached;

    const size = 28.0;
    final bytes = await _render((canvas, canvasSize) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, canvasSize.width - 4, canvasSize.height - 4),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = MapPinColors.ghost);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }, size, size);

    final image = await NOverlayImage.fromByteArray(bytes, cacheKey: key);
    _cache[key] = image;
    return image;
  }

  static Future<Uint8List> _render(
    void Function(Canvas canvas, Size size) painter,
    double width,
    double height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, Size(width, height));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// UI 미리보기용 위젯
class JobTeardropPinWidget extends StatelessWidget {
  const JobTeardropPinWidget({
    super.key,
    required this.bodyColor,
    this.borderColor = Colors.white,
    this.centerLabel = '',
    this.style = MapPinStyle.workplace,
    this.selected = false,
    this.scale = 1,
  });

  final Color bodyColor;
  final Color borderColor;
  final String centerLabel;
  final MapPinStyle style;
  final bool selected;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final width = TeardropMapPinArt.pinWidth * scale;
    final height = TeardropMapPinArt.pinHeight * scale;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MapPinPainter(
          style: style,
          color: bodyColor,
          selected: selected,
        ),
      ),
    );
  }
}

class BusStopPinWidget extends StatelessWidget {
  const BusStopPinWidget({
    super.key,
    required this.bodyColor,
    this.borderColor = Colors.white,
    this.scale = 1,
  });

  final Color bodyColor;
  final Color borderColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final width = TeardropMapPinArt.busWidth * scale;
    final height = TeardropMapPinArt.busHeight * scale;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MapPinPainter(
          style: MapPinStyle.busStop,
          color: bodyColor,
        ),
      ),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  _MapPinPainter({
    required this.style,
    required this.color,
    this.selected = false,
  });

  final MapPinStyle style;
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    TeardropMapPinArt.paintPin(
      canvas,
      size,
      style: style,
      color: color,
      selected: selected,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPinPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.selected != selected;
}
