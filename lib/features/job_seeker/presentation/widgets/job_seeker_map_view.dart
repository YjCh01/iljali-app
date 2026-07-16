import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:map/core/branding/iljari_app_loading_view.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';

import 'package:map/core/geo/map_viewport_bounds.dart';

import 'package:map/core/geo/map_user_location_service.dart';
import 'package:map/core/map/ghost_route_overlay_factory.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/core/map/web/ghost_route_web_overlay_builder.dart';
import 'package:map/features/job_seeker/data/datasources/closed_ghost_route_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';
import 'package:map/core/map/web/job_map_web_marker_factory.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/core/map/web/shuttle_map_web_overlay_builder.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/recruitment_pin_link_factory.dart';

import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';

import 'package:map/features/job_seeker/domain/utils/job_map_viewport_filter.dart';

import 'package:map/features/job_seeker/domain/utils/mock_map_viewport.dart';

import 'package:map/features/job_seeker/presentation/map/job_map_marker_factory.dart';

import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/presentation/map/shuttle_route_overlay_factory.dart';
import 'package:map/features/job_seeker/presentation/map/job_recruitment_map_pin.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_seeker_mock_map.dart';

import 'package:map/features/job_seeker/domain/utils/seeker_home_address_resolver.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';

import 'package:map/features/map_dashboard/presentation/map/warehouse_cluster_options_factory.dart';

import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_floating_insets.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_area_button.dart';



/// 구직자 지도 — Naver Map 클러스터링 또는 mock 지도

class JobSeekerMapView extends StatefulWidget {

  const JobSeekerMapView({

    super.key,

    required this.onPinTap,

    this.onClusterTap,

    this.onMapBackgroundTap,

    this.searchFilter,
    this.shuttleOnlyFilter = false,
    this.minHourlyWage,
    this.workerCategoryFilter,

    this.overlay,
    this.shuttleRoute,
    this.shuttleWorkplace,
    this.recruitmentPins = const [],
    this.selectedRecruitmentPin,
    this.onRecruitmentPinTap,
    this.recruitmentLinkPolylines = const [],

    GetJobMapPinsUseCase? getPins,

  }) : _getPins = getPins;



  final ValueChanged<JobMapPin> onPinTap;

  final ValueChanged<JobMapCluster>? onClusterTap;

  final VoidCallback? onMapBackgroundTap;

  final String? searchFilter;

  /// true면 셔틀 운행 공고만 지도에 표시
  final bool shuttleOnlyFilter;

  /// 설정 시 이 시급(원) 미만인 공고는 제외
  final int? minHourlyWage;

  /// 설정 시 해당 고용 유형인 공고만 표시
  final WorkerCategory? workerCategoryFilter;

  final Widget? overlay;

  final CommuteRoute? shuttleRoute;

  final GeoCoordinate? shuttleWorkplace;

  final List<JobRecruitmentMapPin> recruitmentPins;

  final JobRecruitmentMapPin? selectedRecruitmentPin;

  final ValueChanged<JobRecruitmentMapPin>? onRecruitmentPinTap;

  final List<PushRadiusMapPolyline> recruitmentLinkPolylines;

  final GetJobMapPinsUseCase? _getPins;



  @override

  State<JobSeekerMapView> createState() => JobSeekerMapViewState();

}



class JobSeekerMapViewState extends State<JobSeekerMapView> {
  CommuteRoute? _overrideShuttleRoute;

  CommuteRoute? get _effectiveShuttleRoute =>
      _overrideShuttleRoute ?? widget.shuttleRoute;

  /// 프로그래밍 방식으로 셔틀 노선 표시 (GlobalKey 사용 시)
  void showShuttleRoute(CommuteRoute route) {
    setState(() => _overrideShuttleRoute = route);
    _syncMapOverlays();
  }

  /// 셔틀 노선 오버레이 제거
  void clearShuttleRoute() {
    setState(() => _overrideShuttleRoute = null);
    _syncMapOverlays();
  }

  late final GetJobMapPinsUseCase _getPins = widget._getPins ??

      GetJobMapPinsUseCase(const JobMapPinsLocalDataSource());



  final _mockMapKey = GlobalKey<JobSeekerMockMapState>();



  List<JobMapPin> _catalogPins = [];

  List<JobMapPin> _visiblePins = [];

  List<ClosedGhostRoute> _ghostRoutes = const [];

  MapViewportBounds? _activeViewport;

  bool _loading = true;

  bool _areaSearchPending = false;

  bool _areaSearchLoading = false;

  bool _cameraPromptReady = false;

  /// 지도 최초 idle(로드 직후)에는 검색 CTA를 띄우지 않음 — 웹·네이티브만
  bool _skipNextAreaSearchPrompt = false;

  NaverMapController? _naverController;

  GeoCoordinate? _resolvedHomeCenter;



  @override

  void initState() {

    super.initState();

    unawaited(_loadHomeCenter());

    _loadCatalog(applyInitialViewport: true);

  }

  Future<void> _loadHomeCenter() async {
    final center = await SeekerHomeAddressResolver.resolveMapCenter();
    if (!mounted) return;
    setState(() => _resolvedHomeCenter = center);
  }

  Future<void> _centerOnHomeIfNeeded() async {
    final saved = MapViewportSessionStore.instance
        .peek(MapViewportSessionKeys.seekerHomeMap);
    if (saved != null) {
      await MapCameraHolder.instance.focusPin(
        latitude: saved.latitude,
        longitude: saved.longitude,
        zoom: saved.zoom,
      );
      return;
    }
    final center = _resolvedHomeCenter ??
        await SeekerHomeAddressResolver.resolveMapCenter();
    await MapCameraHolder.instance.focusPin(
      latitude: center.latitude,
      longitude: center.longitude,
      zoom: MapConstants.defaultZoom,
    );
    MapViewportSessionStore.instance.rememberCoordinate(
      MapViewportSessionKeys.seekerHomeMap,
      center: center,
      zoom: MapConstants.defaultZoom,
    );
  }

  GeoCoordinate get _fallbackMapCenter {
    final saved = MapViewportSessionStore.instance
        .peek(MapViewportSessionKeys.seekerHomeMap);
    if (saved != null) return saved.center;
    if (_resolvedHomeCenter != null) return _resolvedHomeCenter!;
    const c = MapConstants.warehouseAreaCenter;
    return GeoCoordinate(latitude: c.latitude, longitude: c.longitude);
  }



  @override

  void didUpdateWidget(covariant JobSeekerMapView oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchFilter != widget.searchFilter ||
        oldWidget.shuttleOnlyFilter != widget.shuttleOnlyFilter ||
        oldWidget.minHourlyWage != widget.minHourlyWage ||
        oldWidget.workerCategoryFilter != widget.workerCategoryFilter) {

      _applyFilters(_activeViewport);

    }

    if (oldWidget.shuttleRoute != widget.shuttleRoute) {

      _overrideShuttleRoute = null;

      _syncMapOverlays();

    }

    if (oldWidget.recruitmentPins != widget.recruitmentPins ||
        oldWidget.selectedRecruitmentPin != widget.selectedRecruitmentPin ||
        oldWidget.recruitmentLinkPolylines != widget.recruitmentLinkPolylines) {
      _syncMapOverlays();
    }

  }



  Future<void> _loadCatalog({bool applyInitialViewport = false}) async {

    setState(() => _loading = true);

    final pins = await _getPins();
    final routes =
        await const ClosedGhostRouteLocalDataSourceImpl().fetchAll();

    if (!mounted) return;

    setState(() {

      _catalogPins = pins;
      _ghostRoutes = routes;

      _loading = false;

      if (applyInitialViewport) {

        _activeViewport = MockMapViewport.initial();

        _cameraPromptReady = true;

      }

    });

    _applyFilters(_activeViewport);

  }



  List<JobMapPin> _textFiltered(List<JobMapPin> pins) {
    var result = pins;
    final filter = widget.searchFilter?.trim();
    if (filter != null && filter.isNotEmpty) {
      result = result
          .where(
            (pin) =>
                pin.post.title.contains(filter) ||
                pin.companyName.contains(filter) ||
                pin.post.warehouseName.contains(filter),
          )
          .toList();
    }
    if (widget.shuttleOnlyFilter) {
      result = result
          .where((pin) {
            final id = pin.post.commuteRouteId?.trim();
            return id != null && id.isNotEmpty;
          })
          .toList();
    }
    final minWage = widget.minHourlyWage;
    if (minWage != null) {
      result = result
          .where((pin) => _parseWageKrw(pin.post.hourlyWage) >= minWage)
          .toList();
    }
    final categoryFilter = widget.workerCategoryFilter;
    if (categoryFilter != null) {
      result = result
          .where((pin) => pin.post.effectiveWorkerCategory == categoryFilter)
          .toList();
    }
    return result;
  }

  int _parseWageKrw(String wage) {
    final digits = wage.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }



  void _applyFilters(MapViewportBounds? viewport) {

    var pins = _textFiltered(_catalogPins);

    if (viewport != null) {

      pins = filterPinsInViewport(

        pins: pins,

        viewport: viewport,

        latitude: (pin) => pin.latitude,

        longitude: (pin) => pin.longitude,

      );

    }

    setState(() => _visiblePins = pins);

    _syncMapOverlays();

  }



  Future<MapViewportBounds> _resolveViewport() async {

    if (!NaverMapPlatform.shouldUseNativeMap) {

      if (NaverMapPlatform.shouldUseWebMap) {

        return MapCameraHolder.instance.getViewportBounds();

      }

      final mockState = _mockMapKey.currentState;

      if (mockState != null) {

        return mockState.currentViewport;

      }

      return MockMapViewport.initial();

    }

    return MapCameraHolder.instance.getViewportBounds();

  }



  Future<void> _searchThisArea() async {
    if (_areaSearchLoading) return;

    setState(() {
      _areaSearchLoading = true;
      _areaSearchPending = false;
    });

    try {
      MapViewportBounds viewport;
      try {
        viewport = await _resolveViewport().timeout(
          const Duration(seconds: 4),
          onTimeout: () => _activeViewport ?? MockMapViewport.initial(),
        );
      } catch (_) {
        viewport = _activeViewport ?? MockMapViewport.initial();
      }
      if (!mounted) return;

      setState(() => _activeViewport = viewport);
      _applyFilters(viewport);
    } finally {
      if (mounted) setState(() => _areaSearchLoading = false);
    }
  }

  void _markAreaSearchPending() {
    if (!_cameraPromptReady || _loading || _areaSearchLoading) return;

    if (_skipNextAreaSearchPrompt) {
      _skipNextAreaSearchPrompt = false;
      return;
    }

    if (_areaSearchPending) return;

    setState(() => _areaSearchPending = true);
  }

  double _areaSearchButtonBottom(BuildContext context) =>
      MapFloatingInsets.searchAreaButtonBottom(context);



  Future<void> _syncMapOverlays() async {

    final controller = _naverController;

    if (controller == null) return;

    await controller.clearOverlays();

    final overlays = <NAddableOverlay>{};

    overlays.addAll(
      await JobMapMarkerFactory.createAll(
        _visiblePins,
        onTap: widget.onPinTap,
      ),
    );

    final route = _effectiveShuttleRoute;

    if (route != null) {
      overlays.addAll(
        await ShuttleRouteOverlayFactory.build(
          route,
          workplace: widget.shuttleWorkplace,
        ),
      );
    }

    for (final ghostRoute in _ghostRoutes) {
      overlays.addAll(await GhostRouteOverlayFactory.build(ghostRoute));
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
          caption: NOverlayCaption(
            text: ExposurePointLabels.title(pin.index),
            color: Colors.white,
            haloColor: color.withValues(alpha: 0.85),
            textSize: 11,
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
            for (final p in line.points)
              NLatLng(p.latitude, p.longitude),
          ],
          width: 4,
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

  void dispose() {

    MapCameraHolder.instance.unbind();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final map = _buildMapContent(context);

    if (widget.overlay == null) return map;

    return Stack(

      fit: StackFit.expand,

      children: [

        map,

        widget.overlay!,

      ],

    );

  }



  Widget _buildMapContent(BuildContext context) {

    if (_loading) {
      return const IljariAppLoadingView();
    }



    if (NaverMapPlatform.shouldUseMockMap) {

      return JobSeekerMockMap(

        key: _mockMapKey,

        pins: _visiblePins,

        shuttleRoute: _effectiveShuttleRoute,
        shuttleWorkplace: widget.shuttleWorkplace,

        onPinTap: widget.onPinTap,

        onClusterTap: widget.onClusterTap,

        onViewportChanged: _markAreaSearchPending,

        areaSearchPending: _areaSearchPending,

        areaSearchLoading: _areaSearchLoading,

        onSearchArea: _searchThisArea,

      );

    }



    if (NaverMapPlatform.shouldUseWebMap) {

      return _buildWebMap(context);

    }



    final safeAreaPadding = MediaQuery.paddingOf(context);



    return Stack(

      fit: StackFit.expand,

      children: [

        NaverMap(

          options: NaverMapViewOptions(

            contentPadding: safeAreaPadding,

            initialCameraPosition: NCameraPosition(

              target: NLatLng(
                _fallbackMapCenter.latitude,
                _fallbackMapCenter.longitude,
              ),

              zoom: MapConstants.warehouseAreaZoom,

            ),

            locationButtonEnable: false,

          ),

          clusterOptions: WarehouseClusterOptionsFactory.create(),

          onMapReady: _handleMapReady,

          onCameraIdle: _cameraPromptReady ? _markAreaSearchPending : null,

          onMapTapped: widget.onMapBackgroundTap == null

              ? null

              : (_, __) => widget.onMapBackgroundTap!(),

        ),

        Positioned(
            left: 16,
            bottom: _areaSearchButtonBottom(context),
            child: MapSearchAreaButton(
              loading: _areaSearchLoading,
              onPressed: _searchThisArea,
            ),
          ),

        MapCurrentLocationButton(
          bottom: MapFloatingInsets.myLocationAboveSearchArea(context),
        ),

      ],

    );

  }



  Future<void> _handleMapReady(NaverMapController controller) async {

    _naverController = controller;

    MapCameraHolder.instance.bind(controller);

    await MapUserLocationService.prepareForMap();

    final viewport = await MapCameraHolder.instance.getViewportBounds();

    if (!mounted) return;

    setState(() {

      _activeViewport = viewport;

      _cameraPromptReady = true;

      _skipNextAreaSearchPrompt = true;

    });

    _applyFilters(viewport);

    await _centerOnHomeIfNeeded();

  }

  Widget _buildWebMap(BuildContext context) {
    final jobMarkers = JobMapWebMarkerFactory.fromPins(_visiblePins);
    final shuttle = _effectiveShuttleRoute;
    final shuttleOverlays = shuttle == null
        ? (
            markers: <NaverMapWebMarkerSpec>[],
            polylines: <NaverMapWebPolylineSpec>[],
          )
        : ShuttleMapWebOverlayBuilder.fromRoute(
            shuttle,
            workplace: widget.shuttleWorkplace,
          );

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

    final linkPolylines = <NaverMapWebPolylineSpec>[
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
            strokeWeight: 4,
          ),
    ];

    final ghostOverlays =
        GhostRouteWebOverlayBuilder.fromRoutes(_ghostRoutes);

    return Stack(
      fit: StackFit.expand,
      children: [
        NaverMapWebWidget(
          clientId: NaverMapPlatform.webClientId,
          initialLatitude: _fallbackMapCenter.latitude,
          initialLongitude: _fallbackMapCenter.longitude,
          initialZoom: MapConstants.warehouseAreaZoom,
          markers: [
            ...jobMarkers,
            ...shuttleOverlays.markers,
            ...recruitmentMarkers,
            ...ghostOverlays.markers,
          ],
          polylines: [
            ...shuttleOverlays.polylines,
            ...linkPolylines,
            ...ghostOverlays.polylines,
          ],
          onMapReady: _handleWebMapReady,
          onCameraIdle: _cameraPromptReady ? _markAreaSearchPending : null,
          onMapTap: widget.onMapBackgroundTap == null
              ? null
              : (_, __) => widget.onMapBackgroundTap!(),
          onMarkerTap: (id) {
            for (final pin in _visiblePins) {
              if (pin.mapMarkerId == id || pin.post.id == id) {
                widget.onPinTap(pin);
                return;
              }
            }
            for (final pin in widget.recruitmentPins) {
              final rid = 'recruitment_pin_${pin.post.id}_${pin.index}';
              if (rid == id) {
                widget.onRecruitmentPinTap?.call(pin);
                return;
              }
            }
          },
        ),

        Positioned(
            left: 16,
            bottom: _areaSearchButtonBottom(context),
            child: MapSearchAreaButton(
              loading: _areaSearchLoading,
              onPressed: _searchThisArea,
            ),
          ),

        MapCurrentLocationButton(
          bottom: MapFloatingInsets.myLocationAboveSearchArea(context),
        ),

      ],

    );

  }



  Future<void> _handleWebMapReady(NaverMapWebController controller) async {

    MapCameraHolder.instance.bindWeb(controller);

    final viewport = await MapCameraHolder.instance.getViewportBounds();

    if (!mounted) return;

    setState(() {

      _activeViewport = viewport;

      _cameraPromptReady = true;

      _skipNextAreaSearchPrompt = true;

    });

    _applyFilters(viewport);

    await _centerOnHomeIfNeeded();

  }

}


