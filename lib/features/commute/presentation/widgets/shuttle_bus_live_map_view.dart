import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/core/map/web/shuttle_map_web_overlay_builder.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/presentation/map/shuttle_route_overlay_factory.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_unavailable_placeholder.dart';

/// 실시간 셔틀 위치 + 노선 + 내 정류장 지도
class ShuttleBusLiveMapView extends StatefulWidget {
  const ShuttleBusLiveMapView({
    super.key,
    required this.route,
    this.busPosition,
    this.highlightStop,
    this.workplace,
  });

  final CommuteRoute route;
  final GeoCoordinate? busPosition;
  final CommuteRouteStop? highlightStop;
  final GeoCoordinate? workplace;

  @override
  State<ShuttleBusLiveMapView> createState() => _ShuttleBusLiveMapViewState();
}

class _ShuttleBusLiveMapViewState extends State<ShuttleBusLiveMapView> {
  NaverMapController? _controller;

  List<GeoCoordinate> get _cameraPoints {
    final points = <GeoCoordinate>[
      for (final stop in widget.route.stops) stop.coordinate,
      if (widget.workplace != null) widget.workplace!,
      if (widget.busPosition != null) widget.busPosition!,
    ];
    return points;
  }

  ({double lat, double lng, double zoom}) get _camera {
    final points = _cameraPoints;
    if (points.isEmpty) {
      return (lat: 37.5665, lng: 126.9780, zoom: 12.0);
    }
    if (points.length == 1) {
      final p = points.first;
      return (lat: p.latitude, lng: p.longitude, zoom: 14.0);
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final latSpan = (maxLat - minLat).abs().clamp(0.004, 1.0);
    final lngSpan = (maxLng - minLng).abs().clamp(0.004, 1.0);
    final span = math.max(latSpan, lngSpan);
    final zoom = switch (span) {
      > 0.35 => 10.0,
      > 0.18 => 11.0,
      > 0.09 => 12.0,
      > 0.045 => 13.0,
      > 0.022 => 14.0,
      _ => 15.0,
    };
    return (
      lat: (minLat + maxLat) / 2,
      lng: (minLng + maxLng) / 2,
      zoom: zoom,
    );
  }

  @override
  void dispose() {
    MapCameraHolder.instance.unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (NaverMapPlatform.shouldUseWebMap) {
      return _buildWebMap();
    }
    if (NaverMapPlatform.shouldUseNativeMap) {
      return _buildNativeMap();
    }
    return const MapUnavailablePlaceholder();
  }

  Widget _buildWebMap() {
    final overlays = ShuttleMapWebOverlayBuilder.fromRoute(
      widget.route,
      workplace: widget.workplace,
      showStopCaptions: false,
    );
    final markers = [...overlays.markers];
    if (widget.busPosition != null) {
      markers.add(
        NaverMapWebMarkerSpec(
          id: 'live_bus_${widget.route.id}',
          latitude: widget.busPosition!.latitude,
          longitude: widget.busPosition!.longitude,
          colorHex: NaverMapWebColors.hex(MapPinColors.selected),
          label: '버스',
          kind: MapPinMarkerKind.notification,
          size: TeardropMapPinArt.pinWidth,
          height: TeardropMapPinArt.pinHeight,
        ),
      );
    }
    if (widget.highlightStop != null) {
      final stop = widget.highlightStop!;
      markers.add(
        NaverMapWebMarkerSpec(
          id: 'my_stop_${stop.id}',
          latitude: stop.coordinate.latitude,
          longitude: stop.coordinate.longitude,
          colorHex: NaverMapWebColors.hex(MapPinColors.active),
          label: '내 정류장',
          kind: MapPinMarkerKind.busStop,
          size: TeardropMapPinArt.busWidth + 4,
          height: TeardropMapPinArt.busHeight + 4,
        ),
      );
    }
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        NaverMapWebWidget(
          clientId: NaverMapPlatform.webClientId,
          initialLatitude: camera.lat,
          initialLongitude: camera.lng,
          initialZoom: camera.zoom,
          markers: markers,
          polylines: overlays.polylines,
          onMapReady: (controller) {
            MapCameraHolder.instance.bindWeb(controller);
          },
        ),
        const MapCurrentLocationButton(),
      ],
    );
  }

  Widget _buildNativeMap() {
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: NLatLng(camera.lat, camera.lng),
              zoom: camera.zoom,
            ),
            locationButtonEnable: false,
          ),
          onMapReady: _onNativeMapReady,
        ),
        MapCurrentLocationButton(controller: _controller),
      ],
    );
  }

  Future<void> _onNativeMapReady(NaverMapController controller) async {
    _controller = controller;
    MapCameraHolder.instance.bind(controller);
    final overlays = await ShuttleRouteOverlayFactory.build(
      widget.route,
      workplace: widget.workplace,
      showStopCaptions: false,
    );
    if (widget.busPosition != null) {
      final busIcon = await MapPinOverlayIconCache.pin(
        style: MapPinStyle.notification,
        bodyColor: MapPinColors.selected,
      );
      overlays.add(
        NMarker(
          id: 'live_bus_${widget.route.id}',
          position: NLatLng(
            widget.busPosition!.latitude,
            widget.busPosition!.longitude,
          ),
          icon: busIcon,
          size: const Size(
            TeardropMapPinArt.pinWidth,
            TeardropMapPinArt.pinHeight,
          ),
          caption: const NOverlayCaption(
            text: '셔틀',
            color: Colors.white,
            haloColor: Colors.black87,
            textSize: 11,
          ),
        ),
      );
    }
    if (widget.highlightStop != null) {
      final stop = widget.highlightStop!;
      final stopIcon = await MapPinOverlayIconCache.busStop(
        bodyColor: MapPinColors.active,
      );
      overlays.add(
        NMarker(
          id: 'my_stop_${stop.id}',
          position: NLatLng(
            stop.coordinate.latitude,
            stop.coordinate.longitude,
          ),
          icon: stopIcon,
          size: const Size(
            TeardropMapPinArt.busWidth + 4,
            TeardropMapPinArt.busHeight + 4,
          ),
          caption: NOverlayCaption(
            text: stop.label.isEmpty ? '내 정류장' : stop.label,
            color: Colors.white,
            haloColor: Colors.black87,
            textSize: 11,
          ),
        ),
      );
    }
    if (!mounted) return;
    controller.addOverlayAll(overlays);
    setState(() {});
  }
}
