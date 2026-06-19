import 'package:flutter/material.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// PUSH·셔틀 거점 지도 — 웹 오버레이 스펙 변환
abstract final class PushRadiusWebOverlayBuilder {
  static ({
    List<NaverMapWebMarkerSpec> markers,
    List<NaverMapWebCircleSpec> circles,
    List<NaverMapWebPolylineSpec> polylines,
  }) build({
    required GeoCoordinate center,
    required int radiusMeters,
    required List<PushRadiusMapOverlayPoint> existingPoints,
    required PushCreditVisualTheme activeTheme,
    required List<PushRadiusMapPolyline> routePolylines,
  }) {
    final markers = <NaverMapWebMarkerSpec>[];
    final circles = <NaverMapWebCircleSpec>[];

    for (final point in existingPoints) {
      final accent = (point.visualTheme ??
              PushCreditVisualTheme.forRecruitPoint(point.pointIndex))
          .accent;
      final alpha = point.draft ? 0.45 : 1.0;
      final tint = accent.withValues(alpha: alpha);
      final fillHex = NaverMapWebColors.hex(tint);
      final strokeHex = NaverMapWebColors.hex(tint.withValues(alpha: 0.55));

      if (point.radiusMeters > 0) {
        circles.add(
          NaverMapWebCircleSpec(
            id: 'push_existing_circle_${point.pointIndex}',
            latitude: point.coordinate.latitude,
            longitude: point.coordinate.longitude,
            radiusMeters: point.radiusMeters.toDouble(),
            fillColorHex: fillHex,
            strokeColorHex: strokeHex,
            fillOpacity: 0.12,
            strokeWeight: 2,
          ),
        );
      }

      markers.add(
        NaverMapWebMarkerSpec(
          id: 'push_existing_marker_${point.pointIndex}',
          latitude: point.coordinate.latitude,
          longitude: point.coordinate.longitude,
          colorHex: fillHex,
          label: point.label.isNotEmpty
              ? point.label.substring(0, 1)
              : '${point.pointIndex + 1}',
          size: 28,
        ),
      );
    }

    if (radiusMeters > 0) {
      circles.add(
        NaverMapWebCircleSpec(
          id: 'push_active_circle',
          latitude: center.latitude,
          longitude: center.longitude,
          radiusMeters: radiusMeters.toDouble(),
          fillColorHex: NaverMapWebColors.hex(activeTheme.accent),
          strokeColorHex: NaverMapWebColors.hex(activeTheme.accent),
          fillOpacity: 0.16,
          strokeWeight: 2.5,
        ),
      );
    }

    if (radiusMeters > 0 || existingPoints.isNotEmpty) {
      markers.add(
        NaverMapWebMarkerSpec(
          id: 'push_active_center',
          latitude: center.latitude,
          longitude: center.longitude,
          colorHex: NaverMapWebColors.hex(activeTheme.accent),
          label: '●',
          isSelected: true,
          size: 32,
        ),
      );
    }

    final polylines = <NaverMapWebPolylineSpec>[];
    for (var i = 0; i < routePolylines.length; i++) {
      final line = routePolylines[i];
      if (line.points.length < 2) continue;
      polylines.add(
        NaverMapWebPolylineSpec(
          id: 'push_route_polyline_$i',
          points: [
            for (final c in line.points)
              (latitude: c.latitude, longitude: c.longitude),
          ],
          colorHex: NaverMapWebColors.hex(line.color),
          strokeWeight: 5,
          dashed: line.dashed,
        ),
      );
    }

    return (markers: markers, circles: circles, polylines: polylines);
  }
}
