import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/seeker_no_show_blacklist_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_ranking_context.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_cluster_list_sheet.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_seeker_map_view.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_bar.dart';
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

class _IndividualMapTabState extends State<IndividualMapTab> {
  JobMapPin? _selectedPin;
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
        _selectedPin = null;
        _clusterPins = null;
        _activeShuttleRoute = null;
        _activeShuttleWorkplace = null;
      });
    }
  }

  Future<void> _selectPin(JobMapPin pin) async {
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
      _selectedPin = pin;
      _activeShuttleRoute = shuttleRoute;
      _activeShuttleWorkplace = GeoCoordinate(
        latitude: pin.latitude,
        longitude: pin.longitude,
      );
    });
  }

  void _openCluster(JobMapCluster cluster) {
    setState(() {
      _selectedPin = null;
      _clusterPins = cluster.rankedPins(context: _rankingContext);
    });
  }

  void _closeCluster() {
    setState(() => _clusterPins = null);
  }

  void _selectPinFromCluster(JobMapPin pin) => _selectPin(pin);

  void _closeSheet() {
    setState(() {
      _selectedPin = null;
      _clusterPins = null;
      _activeShuttleRoute = null;
      _activeShuttleWorkplace = null;
    });
  }

  Future<void> _openSearch() async {
    final warehouse = await Navigator.of(context).pushNamed(
      AppRoutes.search,
    );
    if (!mounted || warehouse is! Warehouse) return;
    setState(() {
      _searchFilter = warehouse.name;
      _selectedPin = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${warehouse.name}」 관련 공고를 지도에서 찾아보세요.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '보관함',
          onPressed: widget.onOpenVaultTab ?? () {},
        ),
      ),
    );
  }

  Future<void> _apply() async {
    if (mounted) _closeSheet();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPin;
    final clusterPins = _clusterPins;
    final showCluster = clusterPins != null && clusterPins.length > 1;
    final showSheet = selected != null;
    final showOverlay = showCluster || showSheet;
    final shuttleActive = _activeShuttleRoute != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: JobSeekerMapView(
            key: ValueKey(widget.reloadToken),
            searchFilter: _searchFilter,
            shuttleOnlyFilter: _shuttleOnlyFilter,
            shuttleRoute: _activeShuttleRoute,
            shuttleWorkplace: _activeShuttleWorkplace,
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
            onMapBackgroundTap: showOverlay ? _closeSheet : null,
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
                padding: const EdgeInsets.only(right: 56),
                child: MapSearchBar(onTap: _openSearch),
              ),
              if (!showOverlay)
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
        if (showOverlay)
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
                        pins: clusterPins!,
                        onClose: _closeCluster,
                        onPinSelected: _selectPinFromCluster,
                      )
                    : selected == null
                        ? const SizedBox.shrink()
                        : JobPostDetailSheet(
                            pin: selected,
                            shuttleRoute: _activeShuttleRoute,
                            vaultRepo: _vaultRepo,
                            onClose: _closeSheet,
                            onApply: _apply,
                            onShowRouteOnMap: () {
                              if (_activeShuttleRoute != null) return;
                              _selectPin(selected);
                            },
                          ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
