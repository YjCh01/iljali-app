import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/ghost_route_overlay_factory.dart';
import 'package:map/core/map/web/ghost_route_web_overlay_builder.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_unavailable_placeholder.dart';

/// 도보 길찾기 — 출발·도착 마커 + 점선 (네이버 v5 embed 대신 앱 지도)
class JobPostWalkingDirectionsMap extends StatefulWidget {
  const JobPostWalkingDirectionsMap({
    super.key,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final double originLatitude;
  final double originLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  @override
  State<JobPostWalkingDirectionsMap> createState() =>
      _JobPostWalkingDirectionsMapState();
}

class _JobPostWalkingDirectionsMapState
    extends State<JobPostWalkingDirectionsMap> {
  NaverMapController? _controller;

  ClosedGhostRoute get _route => ClosedGhostRoute(
        id: '_walking_preview',
        workplaceLatitude: widget.destinationLatitude,
        workplaceLongitude: widget.destinationLongitude,
        stops: [
          GeoCoordinate(
            latitude: widget.originLatitude,
            longitude: widget.originLongitude,
          ),
        ],
      );

  ({double lat, double lng, double zoom}) get _camera {
    final latSpan =
        (widget.destinationLatitude - widget.originLatitude).abs().clamp(0.002, 1.0);
    final lngSpan =
        (widget.destinationLongitude - widget.originLongitude).abs().clamp(0.002, 1.0);
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
      lat: (widget.originLatitude + widget.destinationLatitude) / 2,
      lng: (widget.originLongitude + widget.destinationLongitude) / 2,
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
      final overlays = GhostRouteWebOverlayBuilder.fromRoutes([_route]);
      final camera = _camera;
      return Stack(
        fit: StackFit.expand,
        children: [
          NaverMapWebWidget(
            clientId: NaverMapPlatform.webClientId,
            initialLatitude: camera.lat,
            initialLongitude: camera.lng,
            initialZoom: camera.zoom,
            markers: overlays.markers,
            polylines: overlays.polylines,
            onMapReady: (controller) {
              MapCameraHolder.instance.bindWeb(controller);
            },
          ),
          const MapCurrentLocationButton(),
        ],
      );
    }

    if (NaverMapPlatform.shouldUseNativeMap) {
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

    return const MapUnavailablePlaceholder();
  }

  Future<void> _onNativeMapReady(NaverMapController controller) async {
    _controller = controller;
    MapCameraHolder.instance.bind(controller);
    final overlays = await GhostRouteOverlayFactory.build(_route);
    if (!mounted) return;
    controller.addOverlayAll(overlays);
    setState(() {});
  }
}
