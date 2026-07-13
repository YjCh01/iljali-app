import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:map/core/constants/map_constants.dart';

import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/map_initial_center_policy.dart';
import 'package:map/core/geo/map_user_location_service.dart';
import 'package:map/core/map/web/job_map_web_marker_factory.dart';
import 'package:map/core/map/web/shuttle_map_web_overlay_builder.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/core/utils/naver_map_platform.dart';

import 'package:map/features/commute/presentation/map/shuttle_route_overlay_factory.dart';

import 'package:map/core/map/ghost_route_overlay_factory.dart';
import 'package:map/core/map/web/ghost_route_web_overlay_builder.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';

import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_exposure_mini_map.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/presentation/map/job_map_marker_factory.dart';
import 'package:map/features/job_seeker/presentation/map/job_recruitment_map_pin.dart';
import 'package:map/features/corporate/domain/utils/recruitment_pin_link_factory.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';

import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

import 'package:map/features/map_dashboard/presentation/map/warehouse_cluster_options_factory.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_floating_insets.dart';



/// 기업 홈 — 네이버 지도 + 채용 핀 (미설정 시 mock 격자 지도)

class CorporateHomeNaverMap extends StatefulWidget {

  const CorporateHomeNaverMap({

    super.key,

    required this.pins,

    required this.ownPostIds,

    this.shuttleOverlays = const [],

    this.ghostRoutes = const [],

    this.recruitmentPins = const [],

    this.recruitmentLinkPolylines = const [],

    this.selectedPostId,

    this.centerOnPin,

    required this.onPinTap,

    this.onRecruitmentPinTap,

    this.onShuttleStopTap,

    this.onMapBackgroundTap,

    this.onMapCoordinateTap,

    this.onGhostRouteWorkplaceTap,

    this.onCameraIdle,

    this.onMapReady,

    this.myLocationButtonBottom = 16,

    this.defaultCenterOverride,

  });



  final List<JobMapPin> pins;

  final Set<String> ownPostIds;

  final List<CorporateShuttleMapOverlay> shuttleOverlays;

  final List<ClosedGhostRoute> ghostRoutes;

  final List<JobRecruitmentMapPin> recruitmentPins;

  final List<PushRadiusMapPolyline> recruitmentLinkPolylines;

  final String? selectedPostId;

  final JobMapPin? centerOnPin;

  /// [MapInitialCenterPolicy.corporateBusinessSite] — 강남 데모 대신
  final GeoCoordinate? defaultCenterOverride;

  final ValueChanged<JobMapPin> onPinTap;

  final ValueChanged<JobRecruitmentMapPin>? onRecruitmentPinTap;

  final ValueChanged<CorporateShuttleMapOverlay>? onShuttleStopTap;

  final VoidCallback? onMapBackgroundTap;

  final void Function(double latitude, double longitude)? onMapCoordinateTap;

  final ValueChanged<ClosedGhostRoute>? onGhostRouteWorkplaceTap;

  final VoidCallback? onCameraIdle;

  final VoidCallback? onMapReady;

  final double myLocationButtonBottom;

  @override

  State<CorporateHomeNaverMap> createState() => _CorporateHomeNaverMapState();

}



class _CorporateHomeNaverMapState extends State<CorporateHomeNaverMap> {

  NaverMapController? _controller;

  NaverMapWebController? _webController;

  JobMapPin? _pendingCenterPin;

  bool _webMapFailed = false;



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

    final oldCenter = oldWidget.defaultCenterOverride;
    final nextCenter = widget.defaultCenterOverride;
    if (widget.centerOnPin == null &&
        nextCenter != null &&
        (oldCenter == null ||
            (oldCenter.latitude - nextCenter.latitude).abs() > 0.0001 ||
            (oldCenter.longitude - nextCenter.longitude).abs() > 0.0001) &&
        !MapInitialCenterPolicy.isFallback(nextCenter)) {
      unawaited(_moveCameraToPolicyCenter(nextCenter));
    }

    if (widget.pins != oldWidget.pins ||

        widget.selectedPostId != oldWidget.selectedPostId ||

        widget.ownPostIds != oldWidget.ownPostIds ||

        widget.shuttleOverlays != oldWidget.shuttleOverlays ||

        widget.ghostRoutes != oldWidget.ghostRoutes ||

        widget.recruitmentPins != oldWidget.recruitmentPins ||

        widget.recruitmentLinkPolylines != oldWidget.recruitmentLinkPolylines) {

      _syncOverlays();

    }

  }

  Future<void> _moveCameraToPolicyCenter(GeoCoordinate center) async {
    final web = _webController;
    if (web != null && web.isReady) {
      await web.moveCamera(
        latitude: center.latitude,
        longitude: center.longitude,
        zoom: MapConstants.defaultZoom,
      );
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    final update = NCameraUpdate.withParams(
      target: NLatLng(center.latitude, center.longitude),
      zoom: MapConstants.defaultZoom,
    );
    update.setAnimation(animation: NCameraAnimation.none);
    await controller.updateCamera(update);
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

    widget.onMapReady?.call();

  }



  Future<void> _handleWebMapReady(NaverMapWebController controller) async {

    _webController = controller;

    MapCameraHolder.instance.bindWeb(controller);

    if (_pendingCenterPin != null) {

      await _centerOnPendingPin();

    }

    widget.onMapReady?.call();

  }



  Future<bool> _restoreSavedViewportIfAny() async {

    final saved = MapViewportSessionStore.instance

        .peek(MapViewportSessionKeys.corporateHome);

    if (saved == null) return false;

    if (widget.centerOnPin == null &&
        widget.defaultCenterOverride != null &&
        MapInitialCenterPolicy.isFallback(
          GeoCoordinate(latitude: saved.latitude, longitude: saved.longitude),
        )) {
      MapViewportSessionStore.instance
          .forget(MapViewportSessionKeys.corporateHome);
      return false;
    }

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

    for (var attempt = 0; attempt < 80; attempt++) {
      if (!MapCameraHolder.instance.isReady) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      _pendingCenterPin = null;
      final hasCallout = widget.selectedPostId != null;
      await MapCameraHolder.instance.focusPin(
        latitude: pin.latitude,
        longitude: pin.longitude,
        zoom: MapConstants.defaultZoom,
        pinScreenY: hasCallout
            ? MapFloatingInsets.calloutPinScreenY
            : 0.5,
      );
      return;
    }
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

    final markers = <NClusterableMarker>[];
    for (final pin in widget.pins) {
      final isOwn = widget.ownPostIds.contains(pin.post.id);
      final isSelected = widget.selectedPostId == pin.post.id;
      markers.add(
        await JobMapMarkerFactory.create(
          pin,
          onTap: widget.onPinTap,
          isOwn: isOwn,
          isSelected: isSelected,
        ),
      );
    }
    overlays.addAll(markers);

    for (final entry in widget.shuttleOverlays) {
      overlays.addAll(
        await ShuttleRouteOverlayFactory.build(
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

    for (final route in widget.ghostRoutes) {
      overlays.addAll(
        await GhostRouteOverlayFactory.build(
          route,
          onWorkplaceTap: widget.onGhostRouteWorkplaceTap,
        ),
      );
    }

    for (final pin in widget.recruitmentPins) {
      final color = pin.point.resolvedPinColor;
      final icon = await MapPinOverlayIconCache.pin(
        style: MapPinStyle.notification,
        bodyColor: color,
      );
      overlays.add(
        NMarker(
          id: 'recruitment_pin_${pin.post.id}_${pin.index}',
          position: NLatLng(
            pin.coordinate.latitude,
            pin.coordinate.longitude,
          ),
          icon: icon,
          size: const Size(
            TeardropMapPinArt.jobWidth,
            TeardropMapPinArt.jobHeight,
          ),
        )..setOnTapListener((_) {
            widget.onRecruitmentPinTap?.call(pin);
          }),
      );
    }

    for (var i = 0; i < widget.recruitmentLinkPolylines.length; i++) {
      final line = widget.recruitmentLinkPolylines[i];
      if (line.points.length < 2) continue;
      overlays.add(
        NPathOverlay(
          id: 'recruitment_link_$i',
          coords: [
            for (final p in line.points) NLatLng(p.latitude, p.longitude),
          ],
          width: 3,
          color: line.color,
          outlineColor: Colors.white,
          outlineWidth: 1,
        ),
      );
    }

    if (overlays.isNotEmpty) {

      controller.addOverlayAll(overlays);

    }

  }



  @override

  Widget build(BuildContext context) {

    if (NaverMapPlatform.shouldUseMockMap || _webMapFailed) {

      return CorporateExposureMiniMap(

        pins: widget.pins,

        ownPostIds: widget.ownPostIds,

        shuttleOverlays: widget.shuttleOverlays,

        ghostRoutes: widget.ghostRoutes,

        interactive: true,

        onPinTap: widget.onPinTap,

        onShuttleStopTap: widget.onShuttleStopTap,

        selectedPostId: widget.selectedPostId,

        centerOnPin: widget.centerOnPin,

        initialZoom: MapConstants.defaultZoom,

      );

    }



    final saved = MapViewportSessionStore.instance

        .peek(MapViewportSessionKeys.corporateHome);

    final focus = widget.centerOnPin;

    final policyDefault = widget.defaultCenterOverride;

    // 정책 중심(사업소재지/근무지) > 세션 캐시 > 강남 fallback
    // 세션이 강남이면 정책이 있을 때 무시
    final useSaved = saved != null &&
        (policyDefault == null ||
            !MapInitialCenterPolicy.isFallback(
              GeoCoordinate(
                latitude: saved.latitude,
                longitude: saved.longitude,
              ),
            ));

    final initialLat = focus?.latitude ??
        (useSaved ? saved.latitude : null) ??
        policyDefault?.latitude ??
        MapConstants.warehouseAreaCenter.latitude;

    final initialLng = focus?.longitude ??
        (useSaved ? saved.longitude : null) ??
        policyDefault?.longitude ??
        MapConstants.warehouseAreaCenter.longitude;

    final initialZoom =
        (useSaved ? saved.zoom : null) ?? MapConstants.warehouseAreaZoom;



    if (NaverMapPlatform.shouldUseWebMap) {

      final jobMarkers = JobMapWebMarkerFactory.fromPins(
        widget.pins,
        ownPostIds: widget.ownPostIds,
        selectedPostId: widget.selectedPostId,
      );
      final shuttleOverlays = ShuttleMapWebOverlayBuilder.fromShuttleOverlays(
        widget.shuttleOverlays,
      );
      final ghostOverlays =
          GhostRouteWebOverlayBuilder.fromRoutes(widget.ghostRoutes);

      final recruitmentMarkers = <NaverMapWebMarkerSpec>[
        for (final pin in widget.recruitmentPins)
          NaverMapWebMarkerSpec(
            id: 'recruitment_pin_${pin.post.id}_${pin.index}',
            latitude: pin.coordinate.latitude,
            longitude: pin.coordinate.longitude,
            colorHex: NaverMapWebColors.hex(pin.point.resolvedPinColor),
            label: '',
            kind: MapPinMarkerKind.notification,
            size: TeardropMapPinArt.jobWidth,
            height: TeardropMapPinArt.jobHeight,
          ),
      ];

      final recruitmentPolylines = <NaverMapWebPolylineSpec>[
        for (var i = 0; i < widget.recruitmentLinkPolylines.length; i++)
          if (widget.recruitmentLinkPolylines[i].points.length >= 2)
            NaverMapWebPolylineSpec(
              id: 'recruitment_link_$i',
              points: [
                for (final p in widget.recruitmentLinkPolylines[i].points)
                  (latitude: p.latitude, longitude: p.longitude),
              ],
              colorHex: NaverMapWebColors.hex(
                widget.recruitmentLinkPolylines[i].color,
              ),
              strokeWeight: 3,
            ),
      ];

      return Stack(

        fit: StackFit.expand,

        children: [

          NaverMapWebWidget(

            clientId: NaverMapPlatform.webClientId,

            initialLatitude: initialLat,

            initialLongitude: initialLng,

            initialZoom: initialZoom,

            markers: [
              ...jobMarkers,
              ...shuttleOverlays.markers,
              ...ghostOverlays.markers,
              ...recruitmentMarkers,
            ],
            polylines: [
              ...shuttleOverlays.polylines,
              ...ghostOverlays.polylines,
              ...recruitmentPolylines,
            ],

            onMapReady: _handleWebMapReady,

            onCameraIdle: () {
              unawaited(_persistViewport());
              widget.onCameraIdle?.call();
            },

            onMapTap: widget.onMapCoordinateTap == null &&
                    widget.onMapBackgroundTap == null
                ? null
                : (lat, lng) {
                    if (widget.onMapCoordinateTap != null) {
                      widget.onMapCoordinateTap!(lat, lng);
                    } else {
                      widget.onMapBackgroundTap?.call();
                    }
                  },

            onMarkerTap: (id) {

              for (final pin in widget.pins) {

                if (pin.mapMarkerId == id || pin.post.id == id) {

                  widget.onPinTap(pin);

                  return;

                }

              }

              if (id.startsWith('recruitment_pin_')) {
                for (final pin in widget.recruitmentPins) {
                  if (id == 'recruitment_pin_${pin.post.id}_${pin.index}') {
                    widget.onRecruitmentPinTap?.call(pin);
                    return;
                  }
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

              if (widget.onGhostRouteWorkplaceTap != null) {
                final routeId =
                    GhostRouteOverlayFactory.routeIdFromWorkplaceMarkerId(id);
                if (routeId != null) {
                  for (final route in widget.ghostRoutes) {
                    if (route.id == routeId) {
                      widget.onGhostRouteWorkplaceTap!(route);
                      return;
                    }
                  }
                }
              }

            },

            onInitFailed: () {
              if (mounted) setState(() => _webMapFailed = true);
            },

          ),

          MapCurrentLocationButton(
            bottom: widget.myLocationButtonBottom,
          ),

        ],

      );

    }



    final safeAreaPadding = MediaQuery.paddingOf(context);

    final initialTarget = NLatLng(initialLat, initialLng);



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

          onCameraIdle: () {
            unawaited(_persistViewport());
            widget.onCameraIdle?.call();
          },

          onMapTapped: widget.onMapBackgroundTap == null

              ? null

              : (_, __) => widget.onMapBackgroundTap!(),

        ),

        MapCurrentLocationButton(
          controller: _controller,
          bottom: widget.myLocationButtonBottom,
        ),

      ],

    );

  }

}


