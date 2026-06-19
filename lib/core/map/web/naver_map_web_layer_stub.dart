import 'package:flutter/material.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';

/// Non-web stub — real implementation in [naver_map_web_layer_web.dart].
class NaverMapWebController {
  bool get isReady => false;

  Future<MapViewportBounds> getViewportBounds() async =>
      MapViewportBounds.fromCenter(
        centerLat: 37.5128,
        centerLng: 127.0471,
        latSpan: 0.06,
        lngSpan: 0.06,
      );

  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    double? zoom,
  }) async {}

  Future<void> moveToCurrentLocation() async {}

  Future<({double latitude, double longitude, double zoom})>
      getCameraPosition() async =>
          (latitude: 37.5128, longitude: 127.0471, zoom: 13.0);

  void dispose() {}
}

Future<void> ensureNaverMapsScriptLoaded(String clientId) async {}

typedef NaverMapWebIdleCallback = void Function();
typedef NaverMapWebTapCallback = void Function(double lat, double lng);
typedef NaverMapWebCenterCallback = void Function(double lat, double lng);

class NaverMapWebMarkerSpec {
  const NaverMapWebMarkerSpec({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.colorHex,
    required this.label,
    this.isSelected = false,
    this.isOwn = false,
    this.size = 28,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String colorHex;
  final String label;
  final bool isSelected;
  final bool isOwn;
  final double size;
}

class NaverMapWebCircleSpec {
  const NaverMapWebCircleSpec({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.fillColorHex,
    required this.strokeColorHex,
    this.fillOpacity = 0.16,
    this.strokeOpacity = 1.0,
    this.strokeWeight = 2.5,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String fillColorHex;
  final String strokeColorHex;
  final double fillOpacity;
  final double strokeOpacity;
  final double strokeWeight;
}

class NaverMapWebPolylineSpec {
  const NaverMapWebPolylineSpec({
    required this.id,
    required this.points,
    required this.colorHex,
    this.strokeWeight = 5,
    this.dashed = false,
  });

  final String id;
  final List<({double latitude, double longitude})> points;
  final String colorHex;
  final double strokeWeight;
  final bool dashed;
}

class NaverMapWebWidget extends StatelessWidget {
  const NaverMapWebWidget({
    super.key,
    required this.clientId,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialZoom,
    this.markers = const [],
    this.circles = const [],
    this.polylines = const [],
    this.centerEditable = false,
    this.trackCenterLatitude,
    this.trackCenterLongitude,
    this.onMapReady,
    this.onCameraIdle,
    this.onCenterChanged,
    this.onMapTap,
    this.onMarkerTap,
  });

  final String clientId;
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final List<NaverMapWebMarkerSpec> markers;
  final List<NaverMapWebCircleSpec> circles;
  final List<NaverMapWebPolylineSpec> polylines;
  final bool centerEditable;
  final double? trackCenterLatitude;
  final double? trackCenterLongitude;
  final void Function(NaverMapWebController controller)? onMapReady;
  final NaverMapWebIdleCallback? onCameraIdle;
  final NaverMapWebCenterCallback? onCenterChanged;
  final NaverMapWebTapCallback? onMapTap;
  final void Function(String markerId)? onMarkerTap;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

abstract final class NaverMapWebColors {
  static String hex(Color color) {
    final v = color.toARGB32();
    return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}
