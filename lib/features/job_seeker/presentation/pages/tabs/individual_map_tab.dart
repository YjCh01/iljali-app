import 'package:flutter/material.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/seeker_no_show_blacklist_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_ranking_context.dart';
import 'package:map/features/job_seeker/presentation/pages/job_post_detail_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/closed_ghost_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_cluster_list_sheet.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_hot_jobs_panel.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_seeker_map_view.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_bar.dart';
import 'package:map/features/corporate/domain/utils/recruitment_pin_link_factory.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/job_seeker/presentation/map/job_recruitment_map_pin.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_transport_widgets.dart';

/// 구직자 1번 탭 — 지도 + 공고 클러스터
class IndividualMapTab extends StatefulWidget {
  const IndividualMapTab({
    super.key,
    required this.reloadToken,
    this.onOpenVaultTab,
    this.onApplied,
  });

  final int reloadToken;
  final VoidCallback? onOpenVaultTab;
  final VoidCallback? onApplied;

  @override
  State<IndividualMapTab> createState() => _IndividualMapTabState();
}

enum _MapScreenMode { map, hot }

class _IndividualMapTabState extends State<IndividualMapTab> {
  _MapScreenMode _screenMode = _MapScreenMode.map;
  List<JobMapPin> _allPins = [];
  final _getPins = GetJobMapPinsUseCase(const JobMapPinsLocalDataSource());
  JobMapPin? _calloutPin;
  JobRecruitmentMapPin? _selectedRecruitmentPin;
  List<JobMapPin>? _clusterPins;
  CommuteRoute? _activeShuttleRoute;
  GeoCoordinate? _activeShuttleWorkplace;
  String? _searchFilter;
  bool _shuttleOnlyFilter = false;
  JobBookmarkVaultRepository? _vaultRepo;

  JobMapPinRankingContext get _rankingContext => JobMapPinRankingContext(
        preferShuttle: _shuttleOnlyFilter,
      );

  @override
  void initState() {
    super.initState();
    _initVault();
    _loadPins();
  }

  Future<void> _loadPins() async {
    if (AuthSession.instance.isLoggedIn) {
      await QcSyncBootstrap.pullIfEnabled();
    } else {
      await QcSyncBootstrap.pullPublicCatalogIfEnabled();
    }
    final pins = await _getPins();
    if (!mounted) return;
    setState(() => _allPins = pins);
  }

  Future<void> _initVault() async {
    final user = AuthSession.instance.currentUser;
    final repo = await JobBookmarkVaultRepository.create(user?.email);
    if (!mounted) return;
    setState(() => _vaultRepo = repo);
  }

  @override
  void didUpdateWidget(covariant IndividualMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      setState(() {
        _calloutPin = null;
        _selectedRecruitmentPin = null;
        _clusterPins = null;
        _activeShuttleRoute = null;
        _activeShuttleWorkplace = null;
      });
      _loadPins();
    }
  }

  Future<void> _selectPin(JobMapPin pin) async {
    if (pin.isClosedGhost) {
      setState(() {
        _clusterPins = null;
        _calloutPin = pin;
        _selectedRecruitmentPin = null;
        _activeShuttleRoute = null;
        _activeShuttleWorkplace = GeoCoordinate(
          latitude: pin.latitude,
          longitude: pin.longitude,
        );
      });
      await MapCameraHolder.instance.focusPin(
        latitude: pin.latitude,
        longitude: pin.longitude,
      );
      return;
    }

    if (_searchFilter != null &&
        !pin.post.title.contains(_searchFilter!) &&
        !pin.companyName.contains(_searchFilter!) &&
        !pin.post.warehouseName.contains(_searchFilter!)) {
      return;
    }

    final email = AuthSession.instance.currentUser?.email;
    if (email != null) {
      final blacklist = await SeekerNoShowBlacklistService.create();
      final allowed = await blacklist.consumeMapBrowse(email);
      if (!allowed && mounted) {
        final remaining = await blacklist.remainingMapBrowsesToday(email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining <= 0
                  ? '노쇼 제한으로 오늘 지도 공고 열람 한도(${SeekerNoShowBlacklistService.mapBrowseDailyLimit}회)를 모두 사용했습니다.'
                  : '노쇼 제한으로 지도 공고 열람이 제한됩니다. (오늘 ${remaining}회 남음)',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    _vaultRepo?.recordViewed(pin);
    CommuteRoute? shuttleRoute;
    final routeId = pin.post.commuteRouteId?.trim();
    if (routeId != null && routeId.isNotEmpty) {
      final repo = await CommuteRouteRepository.create();
      final loaded = await repo.findById(routeId);
      if (loaded != null && ShuttleRouteVisibility.hasSeekerVisibleStops(loaded)) {
        shuttleRoute = ShuttleRouteVisibility.forSeekerDisplay(loaded);
      }
    }
    if (!mounted) return;
    setState(() {
      _clusterPins = null;
      _calloutPin = pin;
      _selectedRecruitmentPin = null;
      _activeShuttleRoute = shuttleRoute;
      _activeShuttleWorkplace = GeoCoordinate(
        latitude: pin.latitude,
        longitude: pin.longitude,
      );
    });
    await MapCameraHolder.instance.focusPin(
      latitude: pin.latitude,
      longitude: pin.longitude,
    );
  }

  void _openDetail(JobMapPin pin) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobPostDetailPage(
          pin: pin,
          vaultRepo: _vaultRepo,
          shuttleRoute: _activeShuttleRoute,
          onApplied: widget.onApplied,
          onShowRouteOnMap: () {
            if (_activeShuttleRoute != null) return;
            _selectPin(pin);
          },
        ),
      ),
    );
  }

  void _openCluster(JobMapCluster cluster) {
    setState(() {
      _calloutPin = null;
      _clusterPins = cluster.rankedPins(context: _rankingContext);
    });
  }

  void _closeCluster() {
    setState(() => _clusterPins = null);
  }

  void _selectPinFromCluster(JobMapPin pin) => _selectPin(pin);

  void _closeSheet() {
    setState(() {
      _calloutPin = null;
      _clusterPins = null;
      _selectedRecruitmentPin = null;
      _activeShuttleRoute = null;
      _activeShuttleWorkplace = null;
    });
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.search,
    );
    if (!mounted || result == null) return;

    final filter = switch (result) {
      final String text => text.trim(),
      final Warehouse warehouse => warehouse.name.trim(),
      _ => '',
    };
    if (filter.isEmpty) return;

    setState(() {
      _searchFilter = filter;
      _calloutPin = null;
      _screenMode = _MapScreenMode.map;
    });
  }

  void _openHotPinOnMap(JobMapPin pin) {
    setState(() => _screenMode = _MapScreenMode.map);
    _selectPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final callout = _calloutPin;
    final clusterPins = _clusterPins;
    final showCluster = clusterPins != null && clusterPins.length > 1;
    final showCallout = callout != null;
    final showOverlay = showCluster || showCallout;
    final shuttleActive = _activeShuttleRoute != null;
    final showMap = _screenMode == _MapScreenMode.map;
    final recruitmentPins = JobRecruitmentMapPinFactory.fromPosts(
      _allPins.map((pin) => pin.post),
    );
    final recruitmentLinks = _selectedRecruitmentPin == null
        ? const <PushRadiusMapPolyline>[]
        : RecruitmentPinLinkFactory.seekerSolidLink(
            workplace: _selectedRecruitmentPin!.workplace,
            alertPin: _selectedRecruitmentPin!.coordinate,
            color: _selectedRecruitmentPin!.point.resolvedPinColor,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showMap)
          Positioned.fill(
            child: JobSeekerMapView(
            key: ValueKey(widget.reloadToken),
            searchFilter: _searchFilter,
            shuttleOnlyFilter: _shuttleOnlyFilter,
            shuttleRoute: _activeShuttleRoute,
            shuttleWorkplace: _activeShuttleWorkplace,
            recruitmentPins: recruitmentPins,
            selectedRecruitmentPin: _selectedRecruitmentPin,
            recruitmentLinkPolylines: recruitmentLinks,
            onRecruitmentPinTap: (pin) async {
              setState(() {
                _selectedRecruitmentPin = pin;
                _calloutPin = null;
                _clusterPins = null;
              });
              await MapCameraHolder.instance.focusPin(
                latitude: pin.coordinate.latitude,
                longitude: pin.coordinate.longitude,
              );
            },
            overlay: shuttleActive
                ? Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top + 64,
                        right: 16,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_bus,
                                size: 14,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '셔틀 노선 표시 중',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            onPinTap: _selectPin,
            onClusterTap: _openCluster,
            onMapBackgroundTap: (showOverlay || _selectedRecruitmentPin != null)
                ? _closeSheet
                : null,
          ),
        )
        else
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.background,
              child: JobMapHotJobsPanel(
                pins: _allPins,
                onBannerTap: _openHotPinOnMap,
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<_MapScreenMode>(
                        segments: const [
                          ButtonSegment(
                            value: _MapScreenMode.map,
                            label: Text('지도'),
                            icon: Icon(Icons.map_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: _MapScreenMode.hot,
                            label: Text('인기'),
                            icon: Icon(Icons.local_fire_department_outlined, size: 18),
                          ),
                        ],
                        selected: {_screenMode},
                        onSelectionChanged: (value) {
                          setState(() {
                            _screenMode = value.first;
                            if (_screenMode == _MapScreenMode.hot) {
                              _closeSheet();
                            }
                          });
                        },
                      ),
                    ),
                    if (showMap) ...[
                      const SizedBox(width: 8),
                      MapSearchIconButton(onTap: _openSearch),
                    ],
                  ],
                ),
              ),
              if (showMap && !showOverlay)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      ShuttleMapFilterChip(
                        active: _shuttleOnlyFilter,
                        onChanged: (value) =>
                            setState(() => _shuttleOnlyFilter = value),
                      ),
                      if (_searchFilter != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: InputChip(
                            label: Text('검색: $_searchFilter'),
                            onDeleted: () =>
                                setState(() => _searchFilter = null),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (showMap && showOverlay)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeSheet,
              child: Container(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            offset: showOverlay ? Offset.zero : const Offset(0, 1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: showOverlay ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showOverlay,
                child: showCluster
                    ? JobMapClusterListSheet(
                        pins: clusterPins,
                        onClose: _closeCluster,
                        onPinSelected: _selectPinFromCluster,
                      )
                    : callout == null
                        ? const SizedBox.shrink()
                        : callout.isClosedGhost
                            ? ClosedGhostPinCalloutCard(
                                pin: callout,
                                onClose: _closeSheet,
                              )
                            : JobMapPinCalloutCard(
                                pin: callout,
                                onClose: _closeSheet,
                                onViewDetail: () => _openDetail(callout),
                              ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
