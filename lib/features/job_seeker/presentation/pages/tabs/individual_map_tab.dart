import 'package:flutter/material.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_ranking_context.dart';
import 'package:map/features/job_seeker/domain/entities/map_callout_item.dart';
import 'package:map/features/job_seeker/presentation/pages/job_post_detail_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/closed_ghost_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/event_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_pin_swipe_carousel.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_cluster_list_sheet.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_hot_jobs_panel.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_seeker_map_view.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_bar.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
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
  var _mapViewKey = GlobalKey<JobSeekerMapViewState>();

  /// 고스트/이벤트 핀 전용 — 일반 공고핀·정류장핀 캐러셀은 _calloutPins로 관리
  JobMapPin? _calloutPin;

  /// 스와이프 캐러셀 대상 인근 핀 (탭한 지점 기준 거리순, 화면에 보이는 공고핀 + 활성 노선 정류장핀)
  List<MapCalloutItem> _calloutPins = const [];
  int _calloutIndex = 0;
  GeoCoordinate? _calloutAnchor;
  JobRecruitmentMapPin? _selectedRecruitmentPin;
  List<JobMapPin>? _clusterPins;
  CommuteRoute? _activeShuttleRoute;
  GeoCoordinate? _activeShuttleWorkplace;
  String? _searchFilter;
  bool _shuttleOnlyFilter = false;
  int? _minHourlyWage;
  WorkerCategory? _workerCategoryFilter;
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
      // 스와이프 캐러셀이 열려있는 동안 백그라운드 리로드가 오면 안내 없이
      // 사라지지 않도록 캐러셀 상태(_calloutPin/_calloutPins 등)는 유지한다.
      setState(() {
        _mapViewKey = GlobalKey<JobSeekerMapViewState>();
        _selectedRecruitmentPin = null;
        _clusterPins = null;
      });
      _loadPins();
    }
  }

  Future<void> _selectPin(JobMapPin pin) async {
    if (pin.isClosedGhost || pin.isEvent) {
      setState(() {
        _clusterPins = null;
        _calloutPin = pin;
        _calloutPins = const [];
        _calloutIndex = 0;
        _calloutAnchor = null;
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

    final anchor = GeoCoordinate(latitude: pin.latitude, longitude: pin.longitude);
    final anchorItem = JobPinCalloutItem(pin);
    final items = _buildNeighborItems(anchor: anchor, anchorItem: anchorItem);
    final index = items.indexWhere((i) => i.calloutId == anchorItem.calloutId);
    setState(() {
      _clusterPins = null;
      _calloutPin = null;
      _selectedRecruitmentPin = null;
      _calloutAnchor = anchor;
      _calloutPins = items;
      _calloutIndex = index < 0 ? 0 : index;
    });
    await _focusItem(items.isEmpty ? anchorItem : items[_calloutIndex]);
  }

  /// 셔틀 정류장핀 탭 — 공고핀과 동일하게 인근 핀 스와이프 캐러셀을 연다.
  Future<void> _selectStop(CommuteRoute route, CommuteRouteStop stop) async {
    final anchor = GeoCoordinate(
      latitude: stop.coordinate.latitude,
      longitude: stop.coordinate.longitude,
    );
    final anchorItem = ShuttleStopCalloutItem(route: route, stop: stop);
    final items = _buildNeighborItems(anchor: anchor, anchorItem: anchorItem, route: route);
    final index = items.indexWhere((i) => i.calloutId == anchorItem.calloutId);
    setState(() {
      _clusterPins = null;
      _calloutPin = null;
      _selectedRecruitmentPin = null;
      _calloutAnchor = anchor;
      _calloutPins = items;
      _calloutIndex = index < 0 ? 0 : index;
    });
    await _focusItem(items.isEmpty ? anchorItem : items[_calloutIndex]);
  }

  /// 탭한 지점 기준, 화면에 보이는 공고핀 + (있다면) 활성 노선 정류장핀을 거리순으로 정렬
  /// — 당근마켓 동네지도처럼 스와이프로 인근 핀을 넘겨보는 캐러셀에 사용.
  List<MapCalloutItem> _buildNeighborItems({
    required GeoCoordinate anchor,
    required MapCalloutItem anchorItem,
    CommuteRoute? route,
  }) {
    final visible = _mapViewKey.currentState?.visiblePins ?? const [];
    final items = <MapCalloutItem>[
      for (final p in visible.where((p) => !p.isClosedGhost && !p.isEvent))
        JobPinCalloutItem(p),
      if (route != null)
        for (final stop in route.stops)
          ShuttleStopCalloutItem(route: route, stop: stop),
    ];
    if (!items.any((i) => i.calloutId == anchorItem.calloutId)) {
      items.insert(0, anchorItem);
    }
    items.sort((a, b) {
      final da = GeoDistance.metersBetween(
        anchor,
        GeoCoordinate(latitude: a.latitude, longitude: a.longitude),
      );
      final db = GeoDistance.metersBetween(
        anchor,
        GeoCoordinate(latitude: b.latitude, longitude: b.longitude),
      );
      return da.compareTo(db);
    });
    return items;
  }

  /// 이미 계산된 캐러셀 목록에 (아직 없다면) 활성 노선의 정류장핀을 병합한다.
  List<MapCalloutItem> _withMergedRouteStops(
    List<MapCalloutItem> current,
    GeoCoordinate? anchor,
    CommuteRoute route,
  ) {
    if (anchor == null) return current;
    final alreadyMerged = current.any(
      (i) => i is ShuttleStopCalloutItem && i.route.id == route.id,
    );
    if (alreadyMerged) return current;
    final merged = <MapCalloutItem>[
      ...current,
      for (final stop in route.stops) ShuttleStopCalloutItem(route: route, stop: stop),
    ];
    merged.sort((a, b) {
      final da = GeoDistance.metersBetween(
        anchor,
        GeoCoordinate(latitude: a.latitude, longitude: a.longitude),
      );
      final db = GeoDistance.metersBetween(
        anchor,
        GeoCoordinate(latitude: b.latitude, longitude: b.longitude),
      );
      return da.compareTo(db);
    });
    return merged;
  }

  /// 스와이프 캐러셀에서 다른 항목으로 넘어갔을 때 — 지도 카메라·셔틀 노선 갱신.
  Future<void> _focusItem(MapCalloutItem item) async {
    switch (item) {
      case JobPinCalloutItem(:final pin):
        _vaultRepo?.recordViewed(pin);
        CommuteRoute? shuttleRoute;
        final routeId = pin.post.commuteRouteId?.trim();
        if (routeId != null && routeId.isNotEmpty) {
          final repo = await CommuteRouteRepository.create();
          final loaded = await repo.findById(routeId);
          if (loaded != null &&
              ShuttleRouteVisibility.hasSeekerVisibleStops(loaded)) {
            shuttleRoute = ShuttleRouteVisibility.forSeekerDisplay(loaded);
          }
        }
        if (!mounted) return;
        setState(() {
          _activeShuttleRoute = shuttleRoute;
          _activeShuttleWorkplace = GeoCoordinate(
            latitude: pin.latitude,
            longitude: pin.longitude,
          );
          if (shuttleRoute != null) {
            final merged =
                _withMergedRouteStops(_calloutPins, _calloutAnchor, shuttleRoute);
            _calloutPins = merged;
            final newIndex =
                merged.indexWhere((i) => i.calloutId == item.calloutId);
            if (newIndex >= 0) _calloutIndex = newIndex;
          }
        });
        await MapCameraHolder.instance.focusPin(
          latitude: pin.latitude,
          longitude: pin.longitude,
        );
      case ShuttleStopCalloutItem(:final stop):
        if (!mounted) return;
        setState(() {
          _activeShuttleWorkplace = GeoCoordinate(
            latitude: stop.coordinate.latitude,
            longitude: stop.coordinate.longitude,
          );
        });
        await MapCameraHolder.instance.focusPin(
          latitude: stop.coordinate.latitude,
          longitude: stop.coordinate.longitude,
        );
    }
  }

  Future<void> _onCalloutPageChanged(MapCalloutItem item) async {
    final index = _calloutPins.indexWhere((i) => i.calloutId == item.calloutId);
    setState(() => _calloutIndex = index < 0 ? _calloutIndex : index);
    await _focusItem(item);
  }

  void _onViewDetail(MapCalloutItem item) {
    switch (item) {
      case JobPinCalloutItem(:final pin):
        _openDetail(pin);
      case ShuttleStopCalloutItem(:final route):
        final linked = _findLinkedJobPin(route.id);
        if (linked == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연결된 공고를 찾을 수 없습니다.')),
          );
          return;
        }
        _openDetail(linked);
    }
  }

  JobMapPin? _findLinkedJobPin(String routeId) {
    for (final p in _allPins) {
      if (p.post.commuteRouteId == routeId ||
          p.post.linkedCommuteRouteIds.contains(routeId)) {
        return p;
      }
    }
    return null;
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
      _calloutPins = const [];
      _calloutIndex = 0;
      _calloutAnchor = null;
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
      _calloutPins = const [];
      _calloutIndex = 0;
      _calloutAnchor = null;
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
      _calloutPins = const [];
      _calloutIndex = 0;
      _calloutAnchor = null;
      _screenMode = _MapScreenMode.map;
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_JobFilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobFilterSheet(
        initialMinWage: _minHourlyWage,
        initialCategory: _workerCategoryFilter,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _minHourlyWage = result.minWage;
      _workerCategoryFilter = result.category;
    });
  }

  void _openHotPinOnMap(JobMapPin pin) {
    setState(() => _screenMode = _MapScreenMode.map);
    _selectPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final ghostOrEventCallout = _calloutPin;
    final clusterPins = _clusterPins;
    final showCluster = clusterPins != null && clusterPins.length > 1;
    final showCallout = ghostOrEventCallout != null || _calloutPins.isNotEmpty;
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
            key: _mapViewKey,
            searchFilter: _searchFilter,
            shuttleOnlyFilter: _shuttleOnlyFilter,
            minHourlyWage: _minHourlyWage,
            workerCategoryFilter: _workerCategoryFilter,
            shuttleRoute: _activeShuttleRoute,
            shuttleWorkplace: _activeShuttleWorkplace,
            onStopTap: _selectStop,
            recruitmentPins: recruitmentPins,
            selectedRecruitmentPin: _selectedRecruitmentPin,
            recruitmentLinkPolylines: recruitmentLinks,
            onRecruitmentPinTap: (pin) async {
              setState(() {
                _selectedRecruitmentPin = pin;
                _calloutPin = null;
                _calloutPins = const [];
                _calloutIndex = 0;
                _calloutAnchor = null;
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
                      const SizedBox(width: 8),
                      _JobFilterIconButton(
                        active: _minHourlyWage != null ||
                            _workerCategoryFilter != null,
                        onTap: _openFilterSheet,
                      ),
                    ],
                  ],
                ),
              ),
              if (showMap && !showOverlay)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ShuttleMapFilterChip(
                          active: _shuttleOnlyFilter,
                          onChanged: (value) =>
                              setState(() => _shuttleOnlyFilter = value),
                        ),
                        if (_searchFilter != null) ...[
                          const SizedBox(width: 8),
                          InputChip(
                            label: Text('검색: $_searchFilter'),
                            onDeleted: () =>
                                setState(() => _searchFilter = null),
                          ),
                        ],
                        if (_minHourlyWage != null) ...[
                          const SizedBox(width: 8),
                          InputChip(
                            label: Text('시급 $_minHourlyWage원 이상'),
                            onDeleted: () =>
                                setState(() => _minHourlyWage = null),
                          ),
                        ],
                        if (_workerCategoryFilter != null) ...[
                          const SizedBox(width: 8),
                          InputChip(
                            label: Text(_workerCategoryFilter!.label),
                            onDeleted: () =>
                                setState(() => _workerCategoryFilter = null),
                          ),
                        ],
                      ],
                    ),
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
                    : ghostOrEventCallout != null
                        ? (ghostOrEventCallout.isClosedGhost
                            ? ClosedGhostPinCalloutCard(
                                pin: ghostOrEventCallout,
                                onClose: _closeSheet,
                              )
                            : EventPinCalloutCard(
                                pin: ghostOrEventCallout,
                                onClose: _closeSheet,
                              ))
                        : _calloutPins.isEmpty
                            ? const SizedBox.shrink()
                            : JobMapPinSwipeCarousel(
                                key: ValueKey(_calloutPins.first.calloutId),
                                items: _calloutPins,
                                initialIndex: _calloutIndex,
                                onClose: _closeSheet,
                                onViewDetail: _onViewDetail,
                                onPageChanged: _onCalloutPageChanged,
                              ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JobFilterIconButton extends StatelessWidget {
  const _JobFilterIconButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      color: active ? AppColors.primary : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.tune_rounded,
            size: 22,
            color: active
                ? Colors.white
                : AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _JobFilterResult {
  const _JobFilterResult({this.minWage, this.category});

  final int? minWage;
  final WorkerCategory? category;
}

class _JobFilterSheet extends StatefulWidget {
  const _JobFilterSheet({this.initialMinWage, this.initialCategory});

  final int? initialMinWage;
  final WorkerCategory? initialCategory;

  @override
  State<_JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends State<_JobFilterSheet> {
  static const _wageSteps = [10000, 11000, 12000, 13000, 15000, 20000];

  late int? _minWage = widget.initialMinWage;
  late WorkerCategory? _category = widget.initialCategory;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '공고 필터',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text(
              '최소 시급',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _minWage == null,
                  onSelected: (_) => setState(() => _minWage = null),
                ),
                for (final wage in _wageSteps)
                  ChoiceChip(
                    label: Text('$wage원 이상'),
                    selected: _minWage == wage,
                    onSelected: (_) => setState(() => _minWage = wage),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '고용 형태',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final category in WorkerCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _JobFilterResult(minWage: _minWage, category: _category),
                ),
                child: const Text('적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
