import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/presentation/pages/shuttle_route_edit_page.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_service_action_style.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/corporate/presentation/widgets/select_all_toggle_bar.dart';

class ShuttleStopActivationArgs {
  const ShuttleStopActivationArgs({
    this.preferredRouteId,
    this.jobPostId,
    this.paymentPreference = CorporatePaymentPreference.auto,
  });

  final String? preferredRouteId;
  final String? jobPostId;
  final CorporatePaymentPreference paymentPreference;
}

/// 정류장 등록 화면 pop 결과
class ShuttleStopActivationPageResult {
  const ShuttleStopActivationPageResult({
    required this.registered,
    this.routeIds = const [],
    this.stopCount = 0,
  });

  final bool registered;
  final List<String> routeIds;
  final int stopCount;
}

/// 정류장 표시핀 — 회사 노선 목록 · 정류장 선택 · 등록
class ShuttleStopActivationPage extends StatefulWidget {
  const ShuttleStopActivationPage({super.key, this.args});

  final ShuttleStopActivationArgs? args;

  @override
  State<ShuttleStopActivationPage> createState() =>
      _ShuttleStopActivationPageState();
}

class _ShuttleStopActivationPageState extends State<ShuttleStopActivationPage> {
  List<CommuteRoute> _routes = [];
  final Set<int> _expandedRouteIndices = {};
  bool _loading = true;
  bool _isRegistering = false;
  final Map<String, Set<String>> _selectedByRouteId = {};
  CorporateJobPost? _jobPost;
  Timer? _exposureClock;

  bool get _exposureActive => _jobPost?.isShuttleExposureActive == true;

  bool _isStopLocked(CommuteRoute route, CommuteRouteStop stop) =>
      _jobPost?.isShuttleStopExposureLocked(route.id, stop.id) == true;

  String? _exposureRemainingLabel() {
    final expires = _jobPost?.shuttleExposureExpiresAt;
    if (!_exposureActive || expires == null) return null;
    return ShuttleExposurePolicy.remainingLabel(expires);
  }

  @override
  void dispose() {
    _exposureClock?.cancel();
    super.dispose();
  }

  void _startExposureClock() {
    _exposureClock?.cancel();
    if (!_exposureActive) return;
    _exposureClock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Set<String> _selectedFor(CommuteRoute route) =>
      _selectedByRouteId.putIfAbsent(route.id, () => <String>{});

  int _pendingCount(CommuteRoute route) =>
      ShuttleRouteStopPolicy.pushEligibleStops(route.stops)
          .where((stop) => _selectedFor(route).contains(stop.id))
          .length;

  int get _totalSelectedCount =>
      _routes.fold(0, (sum, route) => sum + _pendingCount(route));

  bool get _canRegister => _totalSelectedCount > 0 && !_isRegistering;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  void _purgeWorkplaceFromSelection(CommuteRoute route) {
    final selected = _selectedFor(route);
    selected.removeWhere((id) {
      for (final stop in route.stops) {
        if (stop.id == id && ShuttleRouteStopPolicy.isWorkplaceStop(stop)) {
          return true;
        }
      }
      return false;
    });
  }

  void _ensureDefaultSelection(CommuteRoute route, {bool preserve = false}) {
    final selected = _selectedFor(route);
    if (preserve && selected.isNotEmpty) {
      _purgeWorkplaceFromSelection(route);
      return;
    }
    selected.clear();
    final registrable = ShuttleRouteStopPolicy.pushEligibleStops(route.stops);
    if (!_exposureActive) {
      selected.addAll(registrable.map((stop) => stop.id));
      return;
    }
    for (final stop in registrable) {
      if (_isStopLocked(route, stop)) {
        selected.add(stop.id);
      }
    }
  }

  void _hydrateRegistrationFromPost(CorporateJobPost post) {
    for (final route in _routes) {
      final registered = post.shuttleRegisteredStopIdsByRoute[route.id];
      if (registered == null || registered.isEmpty) continue;
      final selected = _selectedFor(route)..clear();
      selected.addAll(
        ShuttleRouteStopPolicy.filterRegistrableStopIds(
          stopIds: registered,
          routeStops: route.stops,
        ),
      );
      if (post.isShuttleExposureActive) {
        final paid = ShuttleRouteStopPolicy.filterRegistrableStopIds(
          stopIds: post.shuttlePaidStopIdsByRoute[route.id] ?? const [],
          routeStops: route.stops,
        );
        selected.addAll(paid);
      }
    }
  }

  Future<void> _loadRoutes({bool preserveSelection = false}) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final repo = await CommuteRouteRepository.create();
    final routes =
        await repo.loadForCompany(profile.companyKey).then((list) {
      return list
          .where(
            (route) =>
                ShuttleRouteStopPolicy.pushEligibleStops(route.stops)
                    .isNotEmpty,
          )
          .toList();
    });
    if (!mounted) return;

    final expandedIndices = _expandedRouteIndices
        .where((i) => i >= 0 && i < routes.length)
        .toSet();
    final preferred = widget.args?.preferredRouteId?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      final found = routes.indexWhere((r) => r.id == preferred);
      if (found >= 0) expandedIndices.add(found);
    } else if (expandedIndices.isEmpty && routes.length == 1) {
      expandedIndices.add(0);
    }

    setState(() {
      _routes = routes;
      _expandedRouteIndices
        ..clear()
        ..addAll(expandedIndices);
      _loading = false;
      _isRegistering = false;
      for (final route in routes) {
        _ensureDefaultSelection(route, preserve: preserveSelection);
      }
    });

    final jobPostId = widget.args?.jobPostId?.trim();
    if (jobPostId != null && jobPostId.isNotEmpty) {
      final dataSource = const CorporateJobPostLocalDataSourceImpl();
      final post = await dataSource.findById(jobPostId);
      if (mounted && post != null) {
        var resolved = post.resolveShuttleExposureMetadata();
        resolved = resolved.reconcileShuttleExposureWithRoutes(routes);
        if (resolved != post) {
          await dataSource.updateJobPost(resolved);
        }
        setState(() {
          _jobPost = resolved;
          _hydrateRegistrationFromPost(resolved);
        });
        _startExposureClock();
      }
    }
  }

  void _onRouteExpansionChanged(int index, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedRouteIndices.add(index);
        _ensureDefaultSelection(_routes[index]);
      } else {
        _expandedRouteIndices.remove(index);
      }
    });
  }

  void _popWithResult() {
    Navigator.of(context).pop();
  }

  void _toggleStop(CommuteRoute route, CommuteRouteStop stop) {
    if (ShuttleRouteStopPolicy.isWorkplaceStop(stop)) return;
    if (_isStopLocked(route, stop)) return;
    setState(() {
      final selected = _selectedFor(route);
      if (selected.contains(stop.id)) {
        selected.remove(stop.id);
      } else {
        selected.add(stop.id);
      }
    });
  }

  Iterable<String> _selectableStopIds(CommuteRoute route) sync* {
    for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
      if (!_isStopLocked(route, stop)) yield stop.id;
    }
  }

  void _toggleSelectAllForRoute(CommuteRoute route) {
    final selectable = _selectableStopIds(route).toSet();
    if (selectable.isEmpty) return;
    final selected = _selectedFor(route);
    final allSelected = selectable.every(selected.contains);
    setState(() {
      if (allSelected) {
        selected.removeAll(selectable);
        for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
          if (_isStopLocked(route, stop)) selected.add(stop.id);
        }
      } else {
        selected.addAll(selectable);
      }
    });
  }

  void _toggleSelectAllRoutes() {
    final selectableByRoute = <String, Set<String>>{};
    for (final route in _routes) {
      final ids = _selectableStopIds(route).toSet();
      if (ids.isNotEmpty) selectableByRoute[route.id] = ids;
    }
    if (selectableByRoute.isEmpty) return;

    final allSelected = selectableByRoute.entries.every(
      (entry) => entry.value.every(_selectedFor(
        _routes.firstWhere((route) => route.id == entry.key),
      ).contains),
    );

    setState(() {
      for (final entry in selectableByRoute.entries) {
        final route = _routes.firstWhere((r) => r.id == entry.key);
        final selected = _selectedFor(route);
        if (allSelected) {
          selected.removeAll(entry.value);
          for (final stop
              in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
            if (_isStopLocked(route, stop)) selected.add(stop.id);
          }
        } else {
          selected.addAll(entry.value);
        }
      }
      _expandedRouteIndices.addAll(
        List.generate(_routes.length, (index) => index),
      );
    });
  }

  int get _totalSelectableStopCount => _routes.fold<int>(
        0,
        (sum, route) => sum + _selectableStopIds(route).length,
      );

  int get _totalSelectedSelectableCount {
    var count = 0;
    for (final route in _routes) {
      for (final id in _selectableStopIds(route)) {
        if (_selectedFor(route).contains(id)) count++;
      }
    }
    return count;
  }

  List<GeoCoordinate> _previewPolyline(CommuteRoute route) {
    final selected = _selectedFor(route);
    final pending = route.stops
        .where((s) => selected.contains(s.id))
        .toList(growable: false);
    if (pending.length < ShuttleRouteVisibility.polylineMinActivatedStops) {
      return const [];
    }
    return pending.map((s) => s.coordinate).toList(growable: false);
  }

  List<PushRadiusMapOverlayPoint> _mapOverlays(CommuteRoute route) {
    final selected = _selectedFor(route);
    return [
      for (var i = 0; i < route.stops.length; i++)
        PushRadiusMapOverlayPoint(
          coordinate: route.stops[i].coordinate,
          radiusMeters: 0,
          label: '${i + 1}. ${route.stops[i].label}',
          pointIndex: i,
          draft: !selected.contains(route.stops[i].id),
        ),
    ];
  }

  GeoCoordinate _mapCenter(CommuteRoute route) {
    if (route.stops.isEmpty) return defaultPushMapCenter();
    return route.stops.first.coordinate;
  }

  Future<void> _registerToJobPost() async {
    if (!_canRegister) return;

    final jobPostId = widget.args?.jobPostId?.trim();
    if (jobPostId == null || jobPostId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    final dataSource = const CorporateJobPostLocalDataSourceImpl();
    final post = await dataSource.findById(jobPostId);
    if (!mounted || post == null) return;

    final routeIds = <String>[];
    final registeredByRoute = <String, List<String>>{};
    for (final route in _routes) {
      final selected = ShuttleRouteStopPolicy.filterRegistrableStopIds(
        stopIds: _selectedFor(route),
        routeStops: route.stops,
      );
      if (selected.isEmpty) continue;
      routeIds.add(route.id);
      registeredByRoute[route.id] = selected;
    }

    if (post.isShuttleExposureActive) {
      for (final entry in post.shuttlePaidStopIdsByRoute.entries) {
        if (entry.value.isEmpty) continue;
        CommuteRoute? matchedRoute;
        for (final route in _routes) {
          if (route.id == entry.key) {
            matchedRoute = route;
            break;
          }
        }
        final paidFiltered = matchedRoute == null
            ? entry.value
            : ShuttleRouteStopPolicy.filterRegistrableStopIds(
                stopIds: entry.value,
                routeStops: matchedRoute.stops,
              );
        final merged = <String>{
          ...?registeredByRoute[entry.key],
          ...paidFiltered,
        };
        registeredByRoute[entry.key] = merged.toList(growable: false);
        if (!routeIds.contains(entry.key)) routeIds.add(entry.key);
      }
    }

    setState(() => _isRegistering = true);
    try {
      await dataSource.updateJobPost(
        post.copyWith(
          commuteRouteId:
              routeIds.isNotEmpty ? routeIds.first : post.commuteRouteId,
          linkedCommuteRouteIds: routeIds,
          shuttleRegisteredStopIdsByRoute: registeredByRoute,
          shuttlePaidStopIdsByRoute: post.shuttlePaidStopIdsByRoute,
          shuttleExposurePaidAt: post.shuttleExposurePaidAt,
          hasShuttleRouteOverlay: post.hasShuttleRouteOverlay ||
              post.shuttlePaidStopIdsByRoute.isNotEmpty ||
              post.isShuttleExposureActive,
        ),
      );
      if (!mounted) return;

      final totalStops = registeredByRoute.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      );
      Navigator.of(context).pop(
        ShuttleStopActivationPageResult(
          registered: true,
          routeIds: routeIds,
          stopCount: totalStops,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  Future<void> _createRoute() async {
    final created = await Navigator.of(context).pushNamed<CommuteRoute>(
      AppRoutes.corporateShuttleRouteEdit,
    );
    if (created == null || !mounted) return;
    await _loadRoutes();
    final index = _routes.indexWhere((route) => route.id == created.id);
    if (!mounted) return;
    setState(() {
      if (index >= 0) {
        _expandedRouteIndices.add(index);
        _ensureDefaultSelection(_routes[index]);
      }
    });
  }

  Future<void> _editRoute(CommuteRoute route) async {
    final updated = await Navigator.of(context).pushNamed<CommuteRoute>(
      AppRoutes.corporateShuttleRouteEdit,
      arguments: route,
    );
    if (updated == null || !mounted) return;
    await _loadRoutes(preserveSelection: true);
    final index = _routes.indexWhere((r) => r.id == updated.id);
    if (!mounted || index < 0) return;
    setState(() => _expandedRouteIndices.add(index));
  }

  Future<void> _deleteRoute(CommuteRoute route) async {
    final routeLocked = _routeHasLockedStops(route);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노선 삭제'),
        content: Text(
          '「${route.routeName}」 노선을 삭제할까요?\n'
          '${routeLocked ? '노출 중인 정류장이 포함되어 있습니다. ' : ''}'
          '연결된 공고·정류장 표시핀 설정도 함께 확인해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: CorporateServiceActionStyle.paymentFilled().copyWith(
              backgroundColor: const WidgetStatePropertyAll(Color(0xFFC62828)),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    final repo = await CommuteRouteRepository.create();
    await repo.remove(profile.companyKey, route.id);
    if (!mounted) return;

    _selectedByRouteId.remove(route.id);

    final jobPostId = widget.args?.jobPostId?.trim();
    if (jobPostId != null &&
        jobPostId.isNotEmpty &&
        _jobPost != null &&
        (_jobPost!.shuttleRegisteredStopIdsByRoute.containsKey(route.id) ||
            _jobPost!.shuttlePaidStopIdsByRoute.containsKey(route.id) ||
            _jobPost!.effectiveLinkedCommuteRouteIds.contains(route.id))) {
      final post = _jobPost!;
      final registered = Map<String, List<String>>.from(
        post.shuttleRegisteredStopIdsByRoute,
      )..remove(route.id);
      final paid = Map<String, List<String>>.from(
        post.shuttlePaidStopIdsByRoute,
      )..remove(route.id);
      final linked = post.effectiveLinkedCommuteRouteIds
          .where((id) => id != route.id)
          .toList(growable: false);
      final updated = post.copyWith(
        shuttleRegisteredStopIdsByRoute: registered,
        shuttlePaidStopIdsByRoute: paid,
        linkedCommuteRouteIds: linked,
        commuteRouteId:
            post.commuteRouteId?.trim() == route.id ? null : post.commuteRouteId,
        hasShuttleRouteOverlay:
            linked.isNotEmpty && post.hasShuttleRouteOverlay,
      );
      await const CorporateJobPostLocalDataSourceImpl().updateJobPost(updated);
      if (mounted) setState(() => _jobPost = updated);
    }

    setState(() {
      _expandedRouteIndices.removeWhere(
        (index) => index < 0 || index >= _routes.length
            ? false
            : _routes[index].id == route.id,
      );
    });

    await _loadRoutes(preserveSelection: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${route.routeName}」 노선을 삭제했습니다.')),
    );
  }

  Set<String> _lockedStopIdsFor(CommuteRoute route) => {
        for (final stop in route.stops)
          if (_isStopLocked(route, stop)) stop.id,
      };

  Future<void> _addStopsToRoute(CommuteRoute route) async {
    final priorStopIds = route.stops.map((stop) => stop.id).toSet();
    final updated = await Navigator.of(context).pushNamed<CommuteRoute>(
      AppRoutes.corporateShuttleRouteEdit,
      arguments: ShuttleRouteEditArgs(
        route: route,
        lockedStopIds: _lockedStopIdsFor(route),
      ),
    );
    if (updated == null || !mounted) return;
    await _loadRoutes(preserveSelection: true);
    if (!mounted) return;
    final index = _routes.indexWhere((r) => r.id == updated.id);
    if (index < 0) return;
    setState(() {
      _expandedRouteIndices.add(index);
      final refreshed = _routes[index];
      for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(refreshed.stops)) {
        if (!priorStopIds.contains(stop.id)) {
          _selectedFor(refreshed).add(stop.id);
        }
      }
    });
  }

  Widget _buildStopRow(CommuteRoute route, CommuteRouteStop stop, int index) {
    final routeColor = ShuttleRouteColorUtils.parseHex(route.overlayColorHex);
    final locked = _isStopLocked(route, stop);
    final selected = _selectedFor(route).contains(stop.id);
    final highlighted = selected && !locked;
    final remaining = _exposureRemainingLabel();

    return Material(
      color: locked
          ? AppColors.textSecondary.withValues(alpha: 0.08)
          : highlighted
              ? routeColor.withValues(alpha: 0.14)
              : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: locked ? null : () => _toggleStop(route, stop),
        child: Container(
          height: locked ? 52 : 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: locked
                  ? AppColors.searchBarBorder
                  : highlighted
                      ? routeColor.withValues(alpha: 0.55)
                      : AppColors.searchBarBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: routeColor.withValues(
                    alpha: locked
                        ? 0.08
                        : highlighted
                            ? 0.28
                            : 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: locked
                        ? AppColors.textSecondary.withValues(alpha: 0.55)
                        : routeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: locked
                            ? AppColors.textSecondary.withValues(alpha: 0.7)
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      locked
                          ? '노출 중 · ${remaining ?? 'D+1 23:59:59까지'}'
                          : selected
                              ? '선택됨'
                              : '탭하여 선택',
                      style: TextStyle(
                        fontSize: 11,
                        color: locked
                            ? AppColors.textSecondary.withValues(alpha: 0.8)
                            : selected
                                ? routeColor
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked
                    ? Icons.lock_clock_outlined
                    : selected
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                size: 22,
                color: locked
                    ? AppColors.textSecondary.withValues(alpha: 0.55)
                    : selected
                        ? routeColor
                        : AppColors.textSecondary.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildRegisterBar() {
    final total = _totalSelectedCount;
    if (total <= 0) return null;

    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '선택 $total곳',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _canRegister ? _registerToJobPost : null,
                style: CorporateServiceActionStyle.setupFilled(),
                child: _isRegistering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '등록하기',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _routeHasLockedStops(CommuteRoute route) =>
      route.stops.any((stop) => _isStopLocked(route, stop));

  Widget _buildRouteTile(int index, CommuteRoute route) {
    final routeColor = ShuttleRouteColorUtils.parseHex(route.overlayColorHex);
    final registrableStops =
        ShuttleRouteStopPolicy.pushEligibleStops(route.stops).toList();
    final selectedCount = _pendingCount(route);
    final expanded = _expandedRouteIndices.contains(index);
    final routeLocked = _routeHasLockedStops(route);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded
                ? routeColor.withValues(alpha: 0.45)
                : AppColors.searchBarBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _onRouteExpansionChanged(index, !expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 36,
                      decoration: BoxDecoration(
                        color: routeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.routeName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '정류장 ${registrableStops.length}곳'
                            '${selectedCount > 0 ? ' · 선택 $selectedCount곳' : ''}'
                            '${routeLocked ? ' · 노출 중' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: routeLocked ? '정류장 추가' : '노선 수정',
                      visualDensity: VisualDensity.compact,
                      onPressed: routeLocked
                          ? () => _addStopsToRoute(route)
                          : () => _editRoute(route),
                      icon: Icon(
                        routeLocked
                            ? Icons.add_location_alt_outlined
                            : Icons.edit_outlined,
                        size: 20,
                        color: AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    IconButton(
                      tooltip: '노선 삭제',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteRoute(route),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Color(0xFFC62828),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Text(
                  '「${route.routeName}」 미리보기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 180,
                    child: PushRadiusMapPicker(
                      key: ValueKey(
                        'route_map_${route.id}_${_selectedFor(route).join('-')}',
                      ),
                      center: _mapCenter(route),
                      radiusMeters: 0,
                      hideZeroRadiusLabel: true,
                      centerEditable: false,
                      existingPoints: _mapOverlays(route),
                      polylinePoints: _previewPolyline(route),
                      polylineColor: routeColor,
                      onCenterChanged: (_) {},
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '노선도 내 정류장을 3개 이상 활성화하면 '
                  '근무지까지 이어지는 노선도 전체 라인이 표시됩니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '정류장',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary.withValues(alpha: 0.92),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SelectAllToggleBar(
                  allSelected: _selectableStopIds(route).isNotEmpty &&
                      _selectableStopIds(route)
                          .every(_selectedFor(route).contains),
                  selectableCount: _selectableStopIds(route).length,
                  selectedCount: _selectableStopIds(route)
                      .where(_selectedFor(route).contains)
                      .length,
                  activeColor: routeColor,
                  onToggle: () => _toggleSelectAllForRoute(route),
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < registrableStops.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: _buildStopRow(route, registrableStops[i], i),
                ),
              if (routeLocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: OutlinedButton.icon(
                    onPressed: () => _addStopsToRoute(route),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('정류장 추가'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: routeColor.withValues(alpha: 0.45),
                      ),
                      foregroundColor: routeColor,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registerBar = _buildRegisterBar();
    final listBottomPadding =
        12.0 + (_totalSelectedCount > 0 ? 72.0 : 0.0);

    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: registerBar,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: canPop
            ? IconButton(
                tooltip: '뒤로',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _popWithResult,
              )
            : const SizedBox(width: 48),
        automaticallyImplyLeading: false,
        title: const Text(
          '정류장 표시핀',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '저장된 노선이 없습니다.\n먼저 노선을 등록해 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _createRoute,
                          style: CorporateServiceActionStyle.setupFilled(),
                          icon: const Icon(Icons.add_road_outlined),
                          label: const Text('새 노선 등록'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        '노선도와 정류장을 구성한 다음, 지도에 표시할 정류장을 선택할 수 있습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    if (_totalSelectableStopCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: SelectAllToggleBar(
                          allSelected: _totalSelectableStopCount > 0 &&
                              _totalSelectedSelectableCount ==
                                  _totalSelectableStopCount,
                          selectableCount: _totalSelectableStopCount,
                          selectedCount: _totalSelectedSelectableCount,
                          onToggle: _toggleSelectAllRoutes,
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, listBottomPadding),
                        itemCount: _routes.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == _routes.length) {
                            return OutlinedButton.icon(
                              onPressed: _createRoute,
                              icon: const Icon(Icons.add_road_outlined),
                              label: const Text('새 노선 등록'),
                            );
                          }
                          return _buildRouteTile(index, _routes[index]);
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
