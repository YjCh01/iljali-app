import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/commute_route_polyline.dart';

/// Naver Map 셔틀 경로·정류장 오버레이 생성
abstract final class ShuttleRouteOverlayFactory {
  static const pathOverlayId = 'shuttle_path';
  static const stopIdPrefix = 'shuttle_stop_';
  static const workplaceMarkerId = 'shuttle_workplace';

  static Set<NAddableOverlay> build(
    CommuteRoute route, {
    GeoCoordinate? workplace,
  }) {
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

    for (final stop in route.stops) {
      final timeSuffix = stop.departureTime == null
          ? ''
          : ' · ${stop.departureTime}';
      overlays.add(
        NMarker(
          id: '$stopIdPrefix${stop.id}',
          position: NLatLng(
            stop.coordinate.latitude,
            stop.coordinate.longitude,
          ),
          iconTintColor: color,
          size: const Size(14, 14),
          caption: NOverlayCaption(
            text: '${stop.label}$timeSuffix',
            color: Colors.white,
            haloColor: color.withValues(alpha: 0.85),
            textSize: 11,
          ),
          isHideCollidedCaptions: true,
        ),
      );
    }

    if (workplace != null) {
      overlays.add(
        NMarker(
          id: '${workplaceMarkerId}_${route.id}',
          position: NLatLng(workplace.latitude, workplace.longitude),
          iconTintColor: const Color(0xFF5E35B1),
          size: const Size(16, 16),
          caption: const NOverlayCaption(
            text: '근무지',
            color: Colors.white,
            haloColor: Color(0xFF5E35B1),
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
