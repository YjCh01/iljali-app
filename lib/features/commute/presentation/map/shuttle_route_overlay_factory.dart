import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/commute_route_polyline.dart';

/// Naver Map 셔틀 경로·정류장 오버레이 생성
abstract final class ShuttleRouteOverlayFactory {
  static const pathOverlayId = 'shuttle_path';
  static const stopIdPrefix = 'shuttle_stop_';
  static const workplaceMarkerId = 'shuttle_workplace';

  static Future<Set<NAddableOverlay>> build(
    CommuteRoute route, {
    GeoCoordinate? workplace,
    void Function(CommuteRoute route, CommuteRouteStop stop)? onStopTap,
    bool showStopCaptions = true,
  }) async {
    final points = CommuteRoutePolyline.pathIncludingWorkplace(
      route: route,
      workplace: workplace,
    );
    if (points.length < 2) return {};

    final color = _parseHexColor(route.overlayColorHex);
    final outline = _isLightColor(color) ? Colors.black54 : Colors.white;
    final latLngs =
        points.map((c) => NLatLng(c.latitude, c.longitude)).toList();

    final overlays = <NAddableOverlay>{};
    overlays.addAll(
      _dashedPathOverlays(
        idPrefix: '${pathOverlayId}_${route.id}',
        coords: latLngs,
        color: color,
        outlineColor: outline,
      ),
    );

    for (var i = 0; i < latLngs.length - 1; i++) {
      // Place arrows along densified road segments (every ~Nth vertex pair),
      // not only at stop midpoints (which ignored road bends).
      if (!_shouldPlaceArrowAt(i, latLngs.length)) continue;
      final from = latLngs[i];
      final to = latLngs[i + 1];
      final arrow = await _directionArrowMarker(
        id: '${pathOverlayId}_${route.id}_arrow_$i',
        from: from,
        to: to,
        color: color,
      );
      if (arrow != null) overlays.add(arrow);
    }

    final busIcon = await MapPinOverlayIconCache.busStop(
      bodyColor: MapPinColors.packagePurple,
    );

    for (final stop in route.stops) {
      final timeSuffix = stop.departureTime == null
          ? ''
          : ' · ${stop.departureTime}';
      final marker = NMarker(
        id: '$stopIdPrefix${stop.id}',
        position: NLatLng(
          stop.coordinate.latitude,
          stop.coordinate.longitude,
        ),
        icon: busIcon,
        size: const Size(
          TeardropMapPinArt.busWidth,
          TeardropMapPinArt.busHeight,
        ),
        caption: showStopCaptions
            ? NOverlayCaption(
                text: '${stop.label}$timeSuffix',
                color: Colors.white,
                haloColor: color.withValues(alpha: 0.85),
                textSize: 11,
              )
            : null,
        isHideCollidedCaptions: true,
      );
      if (onStopTap != null) {
        marker.setOnTapListener((_) => onStopTap(route, stop));
      }
      overlays.add(marker);
    }

    if (workplace != null) {
      final workplaceIcon = await MapPinOverlayIconCache.pin(
        style: MapPinStyle.workplace,
        bodyColor: MapPinColors.active,
      );
      overlays.add(
        NMarker(
          id: '${workplaceMarkerId}_${route.id}',
          position: NLatLng(workplace.latitude, workplace.longitude),
          icon: workplaceIcon,
          size: const Size(
            TeardropMapPinArt.jobWidth,
            TeardropMapPinArt.jobHeight,
          ),
          caption: NOverlayCaption(
            text: '근무지',
            color: Colors.white,
            haloColor: MapPinColors.active.withValues(alpha: 0.85),
            textSize: 12,
          ),
          isHideCollidedCaptions: true,
        ),
      );
    }

    return overlays;
  }

  static List<NPathOverlay> _dashedPathOverlays({
    required String idPrefix,
    required List<NLatLng> coords,
    required Color color,
    required Color outlineColor,
  }) {
    final overlays = <NPathOverlay>[];
    var index = 0;
    for (var i = 0; i < coords.length - 1; i++) {
      final segments = _dashBetween(coords[i], coords[i + 1]);
      for (final segment in segments) {
        overlays.add(
          NPathOverlay(
            id: '${idPrefix}_dash_$index',
            coords: segment,
            width: 5,
            color: color,
            outlineColor: outlineColor,
            outlineWidth: 2,
          ),
        );
        index++;
      }
    }
    return overlays;
  }

  /// Sparse arrows on densified polylines; one per segment when short.
  static bool _shouldPlaceArrowAt(int segmentIndex, int pointCount) {
    final segmentCount = pointCount - 1;
    if (segmentCount <= 0) return false;
    if (segmentCount <= 4) return true;
    // Aim for ~3–5 arrows along the full path
    final step = (segmentCount / 4).ceil().clamp(1, segmentCount);
    return segmentIndex % step == 0;
  }

  static double _bearingDegrees(NLatLng a, NLatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearingRad = math.atan2(y, x);
    return (bearingRad * 180 / math.pi + 360) % 360;
  }

  static Future<Uint8List> _renderArrowBytes(
    double bearingDeg,
    Color color,
    double size,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    canvas.translate(size / 2, size / 2);
    canvas.rotate(bearingDeg * math.pi / 180);
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
        ..strokeWidth = size * 0.08
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
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<NMarker?> _directionArrowMarker({
    required String id,
    required NLatLng from,
    required NLatLng to,
    required Color color,
  }) async {
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      return null;
    }
    final mid = NLatLng(
      (from.latitude + to.latitude) / 2,
      (from.longitude + to.longitude) / 2,
    );
    final bearing = _bearingDegrees(from, to);
    const size = 20.0;
    final bytes = await _renderArrowBytes(bearing, color, size);
    final icon = await NOverlayImage.fromByteArray(
      bytes,
      cacheKey: 'shuttle_arrow_v4_${bearing.round()}_${color.toARGB32()}_$size',
    );
    return NMarker(
      id: id,
      position: mid,
      icon: icon,
      size: const Size(size, size),
      isHideCollidedCaptions: true,
    );
  }

  static List<List<NLatLng>> _dashBetween(NLatLng a, NLatLng b) {
    const dashMeters = 55.0;
    const gapMeters = 28.0;
    final total = _haversineMeters(a, b);
    if (total < 1) return [];

    final unitLat = (b.latitude - a.latitude) / total;
    final unitLng = (b.longitude - a.longitude) / total;
    final segments = <List<NLatLng>>[];
    var traveled = 0.0;
    var drawing = true;

    while (traveled < total) {
      final span = drawing ? dashMeters : gapMeters;
      final next = math.min(traveled + span, total);
      if (drawing && next > traveled) {
        segments.add([
          _pointAlong(a, unitLat, unitLng, traveled),
          _pointAlong(a, unitLat, unitLng, next),
        ]);
      }
      traveled = next;
      drawing = !drawing;
    }
    return segments;
  }

  static NLatLng _pointAlong(
    NLatLng start,
    double unitLat,
    double unitLng,
    double meters,
  ) {
    return NLatLng(
      start.latitude + unitLat * meters,
      start.longitude + unitLng * meters,
    );
  }

  static double _haversineMeters(NLatLng a, NLatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static Color _parseHexColor(String hex) {
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFFE53935);
    return Color(parsed);
  }

  static bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.65;
  }
}
