import 'package:flutter/material.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/commute_route_polyline.dart';
import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';
import 'dart:math' as math;

/// Mock 지도 — 다중 셔틀 노선 밀도 페인터
class CorporateShuttleDensityPainter extends CustomPainter {
  CorporateShuttleDensityPainter({
    required this.overlays,
    required this.panOffset,
    required this.zoom,
    required this.mapSize,
  });

  final List<CorporateShuttleMapOverlay> overlays;
  final Offset panOffset;
  final double zoom;
  final Size mapSize;

  Offset _toOffset(double lat, double lng) {
    final center = MapConstants.warehouseAreaCenter;
    final scale = 4200 * math.pow(2, zoom - 12);
    final dx = (lng - center.longitude) * scale +
        mapSize.width / 2 +
        panOffset.dx;
    final dy = (center.latitude - lat) * scale +
        mapSize.height / 2 +
        panOffset.dy;
    return Offset(dx, dy);
  }

  Color _parseHex(String hex) {
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFFE53935);
    return Color(parsed);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final overlay in overlays) {
      _paintRoute(canvas, overlay.route, overlay.workplace);
    }
  }

  void _paintRoute(
    Canvas canvas,
    CommuteRoute route,
    GeoCoordinate? workplace,
  ) {
    final points = CommuteRoutePolyline.pathIncludingWorkplace(
      route: route,
      workplace: workplace,
    );
    if (points.length < 2) {
      _paintStopsOnly(canvas, route);
      return;
    }

    final offsets =
        points.map((c) => _toOffset(c.latitude, c.longitude)).toList();
    final lineColor = _parseHex(route.overlayColorHex);
    final outline = lineColor.computeLuminance() > 0.65
        ? Colors.black54
        : Colors.white;

    _drawDashedPath(
      canvas,
      offsets,
      paint: Paint()
        ..color = outline
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      solid: true,
    );
    _drawDashedPath(
      canvas,
      offsets,
      paint: Paint()
        ..color = lineColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    _paintStopsOnly(canvas, route, lineColor: lineColor, outline: outline);

    if (workplace != null) {
      final workplaceOffset = _toOffset(workplace.latitude, workplace.longitude);
      final workplacePaint = Paint()..color = const Color(0xFF5E35B1);
      canvas.drawCircle(workplaceOffset, 5, workplacePaint);
      canvas.drawCircle(
        workplaceOffset,
        5,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintStopsOnly(
    Canvas canvas,
    CommuteRoute route, {
    Color? lineColor,
    Color? outline,
  }) {
    final color = lineColor ?? _parseHex(route.overlayColorHex);
    final border = outline ??
        (color.computeLuminance() > 0.65 ? Colors.black54 : Colors.white);
    final dotPaint = Paint()..color = color;
    final dotOutline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final stop in route.stops) {
      final offset = _toOffset(
        stop.coordinate.latitude,
        stop.coordinate.longitude,
      );
      canvas.drawCircle(offset, 5, dotPaint);
      canvas.drawCircle(offset, 5, dotOutline);
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    List<Offset> points, {
    required Paint paint,
    bool solid = false,
  }) {
    const dashLength = 12.0;
    const gapLength = 7.0;
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final path = Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);
      if (solid) {
        canvas.drawPath(path, paint);
        continue;
      }
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final next = distance + dashLength;
          canvas.drawPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            paint,
          );
          distance = next + gapLength;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CorporateShuttleDensityPainter oldDelegate) {
    return oldDelegate.overlays != overlays ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoom != zoom ||
        oldDelegate.mapSize != mapSize;
  }
}
