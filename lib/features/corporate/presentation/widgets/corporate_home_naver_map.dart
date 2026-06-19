import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:map/core/constants/map_constants.dart';

import 'package:map/core/geo/map_user_location_service.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/map/web/job_map_web_marker_factory.dart';
import 'package:map/core/map/web/shuttle_map_web_overlay_builder.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/core/utils/naver_map_platform.dart';

import 'package:map/features/commute/presentation/map/shuttle_route_overlay_factory.dart';

import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_exposure_mini_map.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/presentation/map/job_map_marker_factory.dart';

import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

import 'package:map/features/map_dashboard/presentation/map/warehouse_cluster_options_factory.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';



/// 기업 홈 — 네이버 지도 + 채용 핀 (미설정 시 mock 격자 지도)

class CorporateHomeNaverMap extends StatefulWidget {

  const CorporateHomeNaverMap({

    super.key,

    required this.pins,

    required this.ownPostIds,

    this.shuttleOverlays = const [],

    this.selectedPostId,

    this.centerOnPin,

    required this.onPinTap,

    this.onShuttleStopTap,

    this.onMapBackgroundTap,

  });



  final List<JobMapPin> pins;

  final Set<String> ownPostIds;

  final List<CorporateShuttleMapOverlay> shuttleOverlays;

  final String? selectedPostId;

  final JobMapPin? centerOnPin;

  final ValueChanged<JobMapPin> onPinTap;

  final ValueChanged<CorporateShuttleMapOverlay>? onShuttleStopTap;

  final VoidCallback? onMapBackgroundTap;



  @override

  State<CorporateHomeNaverMap> createState() => _CorporateHomeNaverMapState();

}



class _CorporateHomeNaverMapState extends State<CorporateHomeNaverMap> {

  NaverMapController? _controller;

  NaverMapWebController? _webController;

  JobMapPin? _pendingCenterPin;



  @override

  void initState() {

    super.initState();

    _pendingCenterPin = widget.centerOnPin;

  }



  @override

  void didUpdateWidget(CorporateHomeNaverMap oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.centerOnPin != null &&

        widget.centerOnPin != oldWidget.centerOnPin) {

      _pendingCenterPin = widget.centerOnPin;

      _centerOnPendingPin();

    }

    if (widget.pins != oldWidget.pins ||

        widget.selectedPostId != oldWidget.selectedPostId ||

        widget.ownPostIds != oldWidget.ownPostIds ||

        widget.shuttleOverlays != oldWidget.shuttleOverlays) {

      _syncOverlays();

    }

  }



  @override

  void dispose() {

    MapCameraHolder.instance.unbind();

    super.dispose();

  }



  Future<void> _handleMapReady(NaverMapController controller) async {

    _controller = controller;

    MapCameraHolder.instance.bind(controller);

    await MapUserLocationService.prepareForMap();

    await _syncOverlays();

    if (_pendingCenterPin != null) {

      await _centerOnPendingPin();

    } else {

      await _restoreSavedViewportIfAny();

    }

  }



  Future<void> _handleWebMapReady(NaverMapWebController controller) async {

    _webController = controller;

    MapCameraHolder.instance.bindWeb(controller);

    if (_pendingCenterPin != null) {

      await _centerOnPendingPin();

    }

  }



  Future<bool> _restoreSavedViewportIfAny() async {

    final saved = MapViewportSessionStore.instance

        .peek(MapViewportSessionKeys.corporateHome);

    if (saved == null) return false;

    final controller = _controller;

    if (controller == null) return false;

    final update = NCameraUpdate.withParams(

      target: NLatLng(saved.latitude, saved.longitude),

      zoom: saved.zoom,

    );

    update.setAnimation(animation: NCameraAnimation.none);

    await controller.updateCamera(update);

    return true;

  }



  Future<void> _persistViewport() async {

    final web = _webController;

    if (web != null && web.isReady) {

      final camera = await web.getCameraPosition();

      MapViewportSessionStore.instance.remember(

        MapViewportSessionKeys.corporateHome,

        MapViewportSnapshot(

          latitude: camera.latitude,

          longitude: camera.longitude,

          zoom: camera.zoom,

        ),

      );

      return;

    }

    final controller = _controller;

    if (controller == null) return;

    final camera = await controller.getCameraPosition();

    MapViewportSessionStore.instance.remember(

      MapViewportSessionKeys.corporateHome,

      MapViewportSnapshot(

        latitude: camera.target.latitude,

        longitude: camera.target.longitude,

        zoom: camera.zoom,

      ),

    );

  }



  Future<void> _centerOnPendingPin() async {

    final pin = _pendingCenterPin;

    if (pin == null) return;

    _pendingCenterPin = null;

    await MapCameraHolder.instance.focusPin(

      latitude: pin.latitude,

      longitude: pin.longitude,

    );

  }



  CorporateShuttleMapOverlay? _overlayForRoute(String routeId) {

    for (final overlay in widget.shuttleOverlays) {

      if (overlay.route.id == routeId) return overlay;

    }

    return null;

  }



  Future<void> _syncOverlays() async {

    final controller = _controller;

    if (controller == null) return;

    await controller.clearOverlays();



    final overlays = <NAddableOverlay>{};

    overlays.addAll(

      widget.pins.map((pin) {

        final isOwn = widget.ownPostIds.contains(pin.post.id);

        final isSelected = widget.selectedPostId == pin.post.id;

        return JobMapMarkerFactory.create(

          pin,

          onTap: widget.onPinTap,

          isOwn: isOwn,

          isSelected: isSelected,

        );

      }),

    );



    for (final entry in widget.shuttleOverlays) {

      overlays.addAll(

        ShuttleRouteOverlayFactory.build(

          entry.route,

          workplace: entry.workplace,

          showStopCaptions: false,

          onStopTap: widget.onShuttleStopTap == null

              ? null

              : (route) {

                  final overlay = _overlayForRoute(route.id);

                  if (overlay != null) {

                    widget.onShuttleStopTap!(overlay);

                  }

                },

        ),

      );

    }



    if (overlays.isNotEmpty) {

      controller.addOverlayAll(overlays);

    }

  }



  @override

  Widget build(BuildContext context) {

    if (NaverMapPlatform.shouldUseMockMap) {

      return CorporateExposureMiniMap(

        pins: widget.pins,

        ownPostIds: widget.ownPostIds,

        shuttleOverlays: widget.shuttleOverlays,

        interactive: true,

        onPinTap: widget.onPinTap,

        onShuttleStopTap: widget.onShuttleStopTap,

        selectedPostId: widget.selectedPostId,

        centerOnPin: widget.centerOnPin,

        initialZoom: 12.5,

      );

    }



    final saved = MapViewportSessionStore.instance

        .peek(MapViewportSessionKeys.corporateHome);

    final initialLat = saved?.latitude ?? MapConstants.warehouseAreaCenter.latitude;

    final initialLng = saved?.longitude ?? MapConstants.warehouseAreaCenter.longitude;

    final initialZoom = saved?.zoom ?? MapConstants.warehouseAreaZoom;



    if (NaverMapPlatform.shouldUseWebMap) {

      final jobMarkers = JobMapWebMarkerFactory.fromPins(
        widget.pins,
        ownPostIds: widget.ownPostIds,
        selectedPostId: widget.selectedPostId,
      );
      final shuttleOverlays = ShuttleMapWebOverlayBuilder.fromShuttleOverlays(
        widget.shuttleOverlays,
      );

      return Stack(

        fit: StackFit.expand,

        children: [

          NaverMapWebWidget(

            clientId: EnvConfig.naverMapClientId,

            initialLatitude: initialLat,

            initialLongitude: initialLng,

            initialZoom: initialZoom,

            markers: [
              ...jobMarkers,
              ...shuttleOverlays.markers,
            ],
            polylines: shuttleOverlays.polylines,

            onMapReady: _handleWebMapReady,

            onCameraIdle: () => unawaited(_persistViewport()),

            onMapTap: widget.onMapBackgroundTap == null

                ? null

                : (_, __) => widget.onMapBackgroundTap!(),

            onMarkerTap: (id) {

              for (final pin in widget.pins) {

                if (pin.post.id == id) {

                  widget.onPinTap(pin);

                  return;

                }

              }

              if (widget.onShuttleStopTap != null &&
                  id.startsWith('shuttle_stop_')) {
                for (final overlay in widget.shuttleOverlays) {
                  if (id.contains('_${overlay.route.id}_')) {
                    widget.onShuttleStopTap!(overlay);
                    return;
                  }
                }
              }

            },

          ),

          const MapCurrentLocationButton(),

        ],

      );

    }



    final safeAreaPadding = MediaQuery.paddingOf(context);

    final initialTarget = saved == null

        ? MapConstants.warehouseAreaCenter

        : NLatLng(initialLat, initialLng);



    return Stack(

      fit: StackFit.expand,

      children: [

        NaverMap(

          options: NaverMapViewOptions(

            contentPadding: safeAreaPadding,

            initialCameraPosition: NCameraPosition(

              target: initialTarget,

              zoom: initialZoom,

            ),

            locationButtonEnable: false,

          ),

          clusterOptions: WarehouseClusterOptionsFactory.create(),

          onMapReady: _handleMapReady,

          onCameraIdle: () => unawaited(_persistViewport()),

          onMapTapped: widget.onMapBackgroundTap == null

              ? null

              : (_, __) => widget.onMapBackgroundTap!(),

        ),

        MapCurrentLocationButton(controller: _controller),

      ],

    );

  }

}


