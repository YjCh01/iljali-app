import 'dart:async';

import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/geo/map_viewport_bounds.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/core/session/auth_session.dart';

import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';

import 'package:map/features/commute/data/repositories/commute_route_repository.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';

import 'package:map/features/corporate/domain/services/corporate_shuttle_density_loader.dart';

import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';

import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_home_naver_map.dart';

import 'package:map/features/job_seeker/data/datasources/closed_ghost_route_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_route.dart';

import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';

import 'package:map/features/job_seeker/domain/utils/job_map_viewport_filter.dart';

import 'package:map/features/job_seeker/domain/utils/mock_map_viewport.dart';

import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';

import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

import 'package:map/features/map_dashboard/presentation/widgets/map_floating_insets.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_area_button.dart';



/// 기업 홈 — 전체 화면 채용 지도 배경

class CorporateHomeMapBackground extends StatefulWidget {

  const CorporateHomeMapBackground({

    super.key,

    this.focusPostId,

    this.focusPost,

    this.selectedPostId,

    this.onSelectedPinChanged,

    this.onFocusConsumed,

  });



  final String? focusPostId;

  final CorporateJobPost? focusPost;

  final String? selectedPostId;

  final ValueChanged<JobMapPin?>? onSelectedPinChanged;

  final VoidCallback? onFocusConsumed;



  @override

  State<CorporateHomeMapBackground> createState() =>

      _CorporateHomeMapBackgroundState();

}



class _CorporateHomeMapBackgroundState extends State<CorporateHomeMapBackground> {

  static const _sheetMinFraction = 0.26;

  static const _postsSource = CorporateJobPostLocalDataSourceImpl();



  final _getPins = GetJobMapPinsUseCase(const JobMapPinsLocalDataSource());

  final _getPosts = GetCorporateJobPostsUseCase(_postsSource);



  List<JobMapPin> _catalogPins = [];

  List<JobMapPin> _displayPins = [];

  List<CorporateShuttleMapOverlay> _shuttleOverlays = [];

  List<ClosedGhostRoute> _ghostRoutes = const [];

  List<CorporateJobPost> _ownPosts = [];

  Set<String> _ownPostIds = {};

  MapViewportBounds? _activeViewport;

  bool _loading = true;

  bool _showAllPins = true;

  bool _areaSearchPending = false;

  bool _areaSearchLoading = false;

  bool _cameraPromptReady = false;

  bool _skipNextAreaSearchPrompt = false;

  JobMapPin? _centerOnPin;

  String? _appliedFocusPostId;



  @override

  void initState() {

    super.initState();

    _load();

    AuthSession.instance.corporateProfileRevision.addListener(_onProfileChanged);

  }



  @override

  void dispose() {

    AuthSession.instance.corporateProfileRevision

        .removeListener(_onProfileChanged);

    super.dispose();

  }



  @override

  void didUpdateWidget(CorporateHomeMapBackground oldWidget) {

    super.didUpdateWidget(oldWidget);

    if ((widget.focusPostId != oldWidget.focusPostId ||
            widget.focusPost != oldWidget.focusPost) &&
        widget.focusPostId != null) {
      _appliedFocusPostId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_applyFocusPostId());
      });
    }

  }



  void _onProfileChanged() => _load();

  Future<void> _applyFocusPostId() async {
    final id = widget.focusPostId;
    if (id == null || _appliedFocusPostId == id) return;

    CorporateJobPost? post = widget.focusPost;
    if (post == null || post.id != id) {
      for (final candidate in _ownPosts) {
        if (candidate.id == id) {
          post = candidate;
          break;
        }
      }
    }
    post ??= await _postsSource.findById(id);
    if (post == null) return;

    if (_loading) {
      await _load();
      if (!mounted) return;
    }

    _appliedFocusPostId = id;

    final coordinate =
        await JobPostWorkplaceResolver.resolveMapWorkplaceCoordinateAsync(post);

    final usedFallbackCenter = isLikelyDefaultPushMapCenter(coordinate) &&
        post.warehouseName.trim().isNotEmpty &&
        !isDefaultPushMapAddressLabel(post.warehouseName);

    if (!isLikelyDefaultPushMapCenter(coordinate) &&
        (post.workplaceLatitude == null ||
            post.workplaceLongitude == null ||
            isLikelyDefaultPushMapCenter(
              GeoCoordinate(
                latitude: post.workplaceLatitude!,
                longitude: post.workplaceLongitude!,
              ),
            ))) {
      await _postsSource.updateJobPost(
        post.copyWith(
          workplaceLatitude: coordinate.latitude,
          workplaceLongitude: coordinate.longitude,
        ),
      );
      post = post.copyWith(
        workplaceLatitude: coordinate.latitude,
        workplaceLongitude: coordinate.longitude,
      );
    }

    final pin = JobMapPin(
      post: post,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      companyName: post.registeredBy?.companyName ?? post.warehouseName,
      displayTier: post.effectiveMapPinTier,
    );

    if (!mounted) return;

    MapViewportSessionStore.instance.rememberCoordinate(
      MapViewportSessionKeys.corporateHome,
      center: coordinate,
      zoom: MapConstants.defaultZoom,
    );

    setState(() {
      _centerOnPin = pin;
      _showAllPins = true;
      _activeViewport = null;
      if (!_ownPostIds.contains(id)) {
        _ownPosts = [..._ownPosts, post!];
        _ownPostIds = {..._ownPostIds, id};
      }
    });
    _applyPinVisibility();

    await _focusMapWhenReady(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );

    if (!mounted) return;

    if (usedFallbackCenter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '근무지 주소를 찾지 못했습니다. 공고수정에서 근무지를 확인해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    widget.onSelectedPinChanged?.call(pin);
    widget.onFocusConsumed?.call();
  }

  Future<void> _focusMapWhenReady({
    required double latitude,
    required double longitude,
  }) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      if (MapCameraHolder.instance.isReady) {
        await MapCameraHolder.instance.focusPin(
          latitude: latitude,
          longitude: longitude,
          zoom: MapConstants.defaultZoom,
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }



  Future<void> _load() async {

    JobBoardRefresh.consumeIfDirty();

    final pins = await _getPins(includeClosedGhosts: true);

    final posts = await _getPosts();

    final routeRepo = await CommuteRouteRepository.create();

    final shuttleOverlays = await CorporateShuttleDensityLoader.load(

      routeRepo: routeRepo,

      posts: posts,

      pins: pins,

    );

    final ghostRoutes =
        await const ClosedGhostRouteLocalDataSourceImpl().fetchAll();

    final companyKey =

        AuthSession.instance.currentUser?.corporateProfile?.companyKey;



    final ownPosts = posts.where((post) {

      if (companyKey == null) return true;

      final key = post.registeredBy?.companyKey;

      return key == null || key == companyKey;

    }).toList();



    final ownIds = ownPosts.map((p) => p.id).toSet();

    if (!mounted) return;

    setState(() {

      _catalogPins = pins;

      _ownPosts = ownPosts;

      _shuttleOverlays = shuttleOverlays;

      _ghostRoutes = ghostRoutes;

      _ownPostIds = ownIds;

      _loading = false;

    });

    _applyPinVisibility();

    _applyFocusPostId();

  }



  void _applyPinVisibility() {

    var pins = _catalogPins;

    if (!_showAllPins) {

      pins = pins.where((p) => _ownPostIds.contains(p.post.id)).toList();

    }

    if (_activeViewport != null && _centerOnPin == null) {

      pins = filterPinsInViewport(

        pins: pins,

        viewport: _activeViewport!,

        latitude: (pin) => pin.latitude,

        longitude: (pin) => pin.longitude,

      );

    }

    setState(() => _displayPins = pins);

  }



  Future<MapViewportBounds> _resolveViewport() async {

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

      _applyPinVisibility();

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



  Future<void> _handleMapReady() async {

    MapViewportBounds viewport;

    try {

      viewport = await _resolveViewport().timeout(

        const Duration(seconds: 4),

        onTimeout: () => MockMapViewport.initial(),

      );

    } catch (_) {

      viewport = MockMapViewport.initial();

    }

    if (!mounted) return;

    setState(() {

      _activeViewport = viewport;

      _cameraPromptReady = true;

      _skipNextAreaSearchPrompt = true;

    });

    _applyPinVisibility();

  }



  double _areaSearchButtonBottom(BuildContext context) =>
      MapFloatingInsets.draggableSheetSearchButtonBottom(
        context,
        sheetMinFraction: _sheetMinFraction,
      );

  void _onPinTap(JobMapPin pin) {

    setState(() => _centerOnPin = pin);

    widget.onSelectedPinChanged?.call(pin);

  }



  void _onShuttleStopTap(CorporateShuttleMapOverlay overlay) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text('셔틀 노선 · ${overlay.route.routeName}'),

        behavior: SnackBarBehavior.floating,

        duration: const Duration(seconds: 2),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    return Stack(

      fit: StackFit.expand,

      children: [

        if (_loading)

          const ColoredBox(

            color: AppColors.background,

            child: Center(child: CircularProgressIndicator()),

          )

        else

          CorporateHomeNaverMap(
            pins: _displayPins,
            ownPostIds: _ownPostIds,
            shuttleOverlays: _shuttleOverlays,
            ghostRoutes: _ghostRoutes,
            onPinTap: _onPinTap,
            onShuttleStopTap: _onShuttleStopTap,
            selectedPostId: widget.selectedPostId,
            centerOnPin: _centerOnPin,
            onMapBackgroundTap: () => widget.onSelectedPinChanged?.call(null),
            onCameraIdle: _cameraPromptReady ? _markAreaSearchPending : null,
            onMapReady: _handleMapReady,
            myLocationButtonBottom:
                MapFloatingInsets.myLocationAboveDraggableSheet(
              context,
              sheetMinFraction: _sheetMinFraction,
            ),
          ),

        if (!_loading && _areaSearchPending)

          Positioned(

            left: 0,

            right: 0,

            bottom: _areaSearchButtonBottom(context),

            child: Center(

              child: MapSearchAreaButton(

                loading: _areaSearchLoading,

                onPressed: _searchThisArea,

              ),

            ),

          ),

        Positioned(

          left: 16,

          top: 8,

          child: SafeArea(

            bottom: false,

            child: _MapFilterChip(

              label: _showAllPins ? '주변 공고 포함' : '내 공고만',

              onTap: () {

                setState(() => _showAllPins = !_showAllPins);

                _applyPinVisibility();

              },

            ),

          ),

        ),

      ],

    );

  }

}



class _MapFilterChip extends StatelessWidget {

  const _MapFilterChip({required this.label, required this.onTap});



  final String label;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.white.withValues(alpha: 0.94),

      elevation: 2,

      shadowColor: Colors.black26,

      borderRadius: BorderRadius.circular(20),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Padding(

          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              Icon(

                Icons.layers_outlined,

                size: 16,

                color: AppColors.primary.withValues(alpha: 0.9),

              ),

              const SizedBox(width: 6),

              Text(

                label,

                style: const TextStyle(

                  fontSize: 12,

                  fontWeight: FontWeight.w700,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}

