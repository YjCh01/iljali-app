import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';

/// mock 지도 pan/zoom → 위경도 viewport
abstract final class MockMapViewport {
  static const _baseScale = 4200.0;

  static MapViewportBounds resolve({
    required Size mapSize,
    required Offset panOffset,
    required double zoom,
  }) {
    final zoomScale = math.pow(2, zoom - 12.5).toDouble();
    final scale = _baseScale * zoomScale;
    final centerLng =
        MapConstants.warehouseAreaCenter.longitude + panOffset.dx / scale;
    final centerLat =
        MapConstants.warehouseAreaCenter.latitude - panOffset.dy / scale;
    final lngSpan = mapSize.width / scale;
    final latSpan = mapSize.height / scale;
    return MapViewportBounds.fromCenter(
      centerLat: centerLat,
      centerLng: centerLng,
      latSpan: latSpan,
      lngSpan: lngSpan,
    );
  }

  /// mock 지도 — 좌표가 화면 중앙에 오도록 pan offset
  static Offset panOffsetToCenterOn({
    required GeoCoordinate target,
    required double zoom,
  }) {
    final zoomScale = math.pow(2, zoom - 12.5).toDouble();
    final scale = _baseScale * zoomScale;
    final dx =
        (target.longitude - MapConstants.warehouseAreaCenter.longitude) * scale;
    final dy = (MapConstants.warehouseAreaCenter.latitude - target.latitude) *
        scale;
    return Offset(dx, dy);
  }

  static MapViewportBounds initial({Size? mapSize}) {
    final size = mapSize ?? const Size(360, 640);
    return resolve(mapSize: size, panOffset: Offset.zero, zoom: 12.5);
  }
}
