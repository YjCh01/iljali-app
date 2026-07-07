import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';

/// 유령노선도 — 회색 점선 + 작은 번호 정류장 + 근무지 점 (대형 유령핀 없음)
abstract final class GhostRouteOverlayFactory {
  static const pathIdPrefix = 'ghost_route_path_';
  static const stopIdPrefix = 'ghost_route_stop_';
  static const workplaceMarkerIdPrefix = 'ghost_route_workplace_';

  @Deprecated('Use workplaceMarkerIdFor')
  static const workplaceMarkerId = workplaceMarkerIdPrefix;

  static String workplaceMarkerIdFor(String routeId) =>
      '$workplaceMarkerIdPrefix$routeId';

  static String? routeIdFromWorkplaceMarkerId(String markerId) {
    if (!markerId.startsWith(workplaceMarkerIdPrefix)) return null;
    final id = markerId.substring(workplaceMarkerIdPrefix.length);
    return id.isEmpty ? null : id;
  }

  static Future<Set<NAddableOverlay>> build(
    ClosedGhostRoute route, {
    void Function(ClosedGhostRoute route)? onWorkplaceTap,
  }) async {
    const color = MapPinColors.ghost;
    final overlays = <NAddableOverlay>{};
    final hasWorkplace = _hasWorkplace(route);
    final path = hasWorkplace ? route.travelPath : route.stops;

    if (hasWorkplace && path.length >= 2) {
      final latLngs = path.map((c) => NLatLng(c.latitude, c.longitude)).toList();
      overlays.addAll(
        _dashedPathOverlays(
          idPrefix: '$pathIdPrefix${route.id}',
          coords: latLngs,
          color: color,
        ),
      );
    }

    for (var i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];
      final icon = await MapPinOverlayIconCache.ghostRouteStopDot(
        number: i + 1,
      );
      overlays.add(
        NMarker(
          id: '$stopIdPrefix${route.id}_$i',
          position: NLatLng(stop.latitude, stop.longitude),
          icon: icon,
          size: const Size(26, 26),
          anchor: const NPoint(0.5, 0.5),
        ),
      );
    }

    if (hasWorkplace) {
      final workplaceIcon = await MapPinOverlayIconCache.ghostRouteWorkplaceDot();
      final marker = NMarker(
        id: workplaceMarkerIdFor(route.id),
        position: NLatLng(route.workplaceLatitude, route.workplaceLongitude),
        icon: workplaceIcon,
        size: const Size(28, 28),
        anchor: const NPoint(0.5, 0.5),
        caption: const NOverlayCaption(
          text: '근무지',
          color: Colors.white,
          haloColor: MapPinColors.ghost,
          textSize: 11,
        ),
        isHideCollidedCaptions: true,
      );
      if (onWorkplaceTap != null && !route.id.startsWith('_')) {
        marker.setOnTapListener((_) => onWorkplaceTap(route));
      }
      overlays.add(marker);
    }

    return overlays;
  }

  static bool _hasWorkplace(ClosedGhostRoute route) =>
      route.workplaceLatitude.abs() > 1e-6 ||
      route.workplaceLongitude.abs() > 1e-6;

  static List<NPathOverlay> _dashedPathOverlays({
    required String idPrefix,
    required List<NLatLng> coords,
    required Color color,
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
            width: 4,
            color: color.withValues(alpha: 0.85),
            outlineColor: Colors.white.withValues(alpha: 0.5),
            outlineWidth: 1.5,
          ),
        );
        index++;
      }
    }
    return overlays;
  }

  static List<List<NLatLng>> _dashBetween(NLatLng a, NLatLng b) {
    const dashMeters = 48.0;
    const gapMeters = 26.0;
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
    const metersPerDegLat = 111320.0;
    final meanLat = (a.latitude + b.latitude) / 2;
    final dx = (b.longitude - a.longitude) *
        metersPerDegLat *
        math.cos(meanLat * math.pi / 180);
    final dy = (b.latitude - a.latitude) * metersPerDegLat;
    return math.sqrt(dx * dx + dy * dy);
  }
}
