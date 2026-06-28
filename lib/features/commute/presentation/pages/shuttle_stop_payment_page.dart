import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/services/shuttle_stop_activation_service.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/core/widgets/map_form_split_layout.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/corporate/presentation/widgets/select_all_toggle_bar.dart';

class ShuttleStopPaymentArgs {
  const ShuttleStopPaymentArgs({
    required this.jobPostId,
    this.paymentPreference = CorporatePaymentPreference.auto,
  });

  final String jobPostId;
  final CorporatePaymentPreference paymentPreference;
}

class ShuttleStopPaymentPageResult {
  const ShuttleStopPaymentPageResult({required this.paid});

  final bool paid;
}

class _ShuttlePayRow {
  const _ShuttlePayRow({
    required this.routeId,
    required this.routeName,
    required this.routeColor,
    required this.stop,
    required this.stopIndex,
  });

  final String routeId;
  final String routeName;
  final Color routeColor;
  final CommuteRouteStop stop;
  final int stopIndex;
}

/// 정류장 표시핀 결제 — 정류장 선택 · 노출 활성화
class ShuttleStopPaymentPage extends StatefulWidget {
  const ShuttleStopPaymentPage({super.key, this.args});

  final ShuttleStopPaymentArgs? args;

  @override
  State<ShuttleStopPaymentPage> createState() => _ShuttleStopPaymentPageState();
}

class _ShuttleStopPaymentPageState extends State<ShuttleStopPaymentPage> {
  final List<_ShuttlePayRow> _rows = [];
  final Map<String, CommuteRoute> _routesById = {};
  final Set<String> _selectedStopIds = <String>{};
  CorporateJobPost? _jobPost;
  bool _loading = true;
  bool _paying = false;

  bool _isStopLocked(_ShuttlePayRow row) =>
      _jobPost?.isShuttleStopExposureLocked(row.routeId, row.stop.id) == true;

  int get _chargeableCount => _rows
      .where(
        (row) =>
            _selectedStopIds.contains(row.stop.id) && !_isStopLocked(row),
      )
      .length;

  int get _selectedCount =>
      _rows.where((row) => _selectedStopIds.contains(row.stop.id)).length;

  bool get _canCheckout => _chargeableCount > 0 && !_paying;

  int get _checkoutTotalKrw =>
      _chargeableCount * PushPackageCatalog.exposureUnitPriceKrw;

  String get _checkoutButtonLabel {
    if (_paying) return '결제하기';
    if (_selectedCount == 0) return '노출할 정류장을 선택해 주세요';
    if (_chargeableCount == 0) return '노출 중인 정류장은 결제할 수 없습니다';
    return '결제하기';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jobPostId = widget.args?.jobPostId.trim();
    if (jobPostId == null || jobPostId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final post =
        await const CorporateJobPostLocalDataSourceImpl().findById(jobPostId);
    if (!mounted) return;
    if (post == null || !post.hasShuttlePinRegistration) {
      setState(() => _loading = false);
      return;
    }

    final resolved = post.resolveShuttleExposureMetadata();
    final repo = await CommuteRouteRepository.create();
    final routesById = <String, CommuteRoute>{};

    for (final entry in resolved.shuttleRegisteredStopIdsByRoute.entries) {
      final routeId = entry.key.trim();
      if (routeId.isEmpty) continue;
      final route = await repo.findById(routeId);
      if (route != null) routesById[routeId] = route;
    }

    final reconciled =
        resolved.reconcileShuttleExposureWithRoutes(routesById.values);
    if (reconciled != post) {
      await const CorporateJobPostLocalDataSourceImpl().updateJobPost(reconciled);
    }

    final rows = <_ShuttlePayRow>[];

    for (final entry in reconciled.shuttleRegisteredStopIdsByRoute.entries) {
      final routeId = entry.key.trim();
      if (routeId.isEmpty || entry.value.isEmpty) continue;

      final route = routesById[routeId] ?? await repo.findById(routeId);
      if (route == null) continue;
      routesById[route.id] = route;
      final routeColor = ShuttleRouteColorUtils.parseHex(route.overlayColorHex);

      for (final stopId in entry.value) {
        final index = route.stops.indexWhere((stop) => stop.id == stopId);
        if (index < 0) continue;
        final stop = route.stops[index];
        if (ShuttleRouteStopPolicy.isWorkplaceStop(stop)) continue;
        rows.add(
          _ShuttlePayRow(
            routeId: route.id,
            routeName: route.routeName,
            routeColor: routeColor,
            stop: stop,
            stopIndex: index,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _jobPost = reconciled;
      _rows
        ..clear()
        ..addAll(rows);
      _routesById
        ..clear()
        ..addAll(routesById);
      _selectedStopIds
        ..clear()
        ..addAll([
          for (final row in rows)
            if (!_isStopLockedForPost(reconciled, row)) row.stop.id,
        ]);
      _loading = false;
    });
  }

  bool _isStopLockedForPost(CorporateJobPost post, _ShuttlePayRow row) =>
      post.isShuttleStopExposureLocked(row.routeId, row.stop.id);

  void _toggleStop(_ShuttlePayRow row) {
    if (_isStopLocked(row)) return;
    setState(() {
      if (_selectedStopIds.contains(row.stop.id)) {
        _selectedStopIds.remove(row.stop.id);
      } else {
        _selectedStopIds.add(row.stop.id);
      }
    });
  }

  List<_ShuttlePayRow> get _chargeableRows =>
      _rows.where((row) => !_isStopLocked(row)).toList();

  void _toggleSelectAllChargeable() {
    final chargeable = _chargeableRows;
    if (chargeable.isEmpty) return;
    final ids = chargeable.map((row) => row.stop.id).toSet();
    final allSelected = ids.every(_selectedStopIds.contains);
    setState(() {
      if (allSelected) {
        _selectedStopIds.removeAll(ids);
      } else {
        _selectedStopIds.addAll(ids);
      }
    });
  }

  List<ShuttleRouteStopSelection> _buildRouteSelections() {
    final selectedByRoute = <String, Set<String>>{};
    for (final row in _rows) {
      if (!_selectedStopIds.contains(row.stop.id) || _isStopLocked(row)) {
        continue;
      }
      selectedByRoute.putIfAbsent(row.routeId, () => <String>{}).add(row.stop.id);
    }

    return [
      for (final entry in selectedByRoute.entries)
        (
          routeId: entry.key,
          stops: _routesById[entry.key]!.stops,
          selectedStopIds: entry.value,
        ),
    ];
  }

  Future<void> _checkout() async {
    if (!_canCheckout) return;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final jobPostId = widget.args?.jobPostId.trim();
    if (profile == null || jobPostId == null || jobPostId.isEmpty) return;

    final routeSelections = _buildRouteSelections();
    if (routeSelections.isEmpty) return;

    setState(() => _paying = true);
    try {
      final service = ShuttleStopActivationService();
      final result = await service.activateRegisteredStopsForPost(
        context: context,
        profile: profile,
        jobPostId: jobPostId,
        routeSelections: routeSelections,
        paymentPreference:
            widget.args?.paymentPreference ?? CorporatePaymentPreference.auto,
      );
      if (!mounted) return;

      if (result.needsShop) {
        await Navigator.of(context).pushNamed(
          AppRoutes.corporatePushPackageShop,
          arguments: PushPackageCatalog.exposureSingleId,
        );
        return;
      }

      if (!result.success) {
        if (result.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message!)),
          );
        }
        return;
      }

      final repo = await CommuteRouteRepository.create();
      if (result.updatedStopsByRouteId != null) {
        for (final entry in result.updatedStopsByRouteId!.entries) {
          final route = await repo.findById(entry.key);
          if (route == null) continue;
          await repo.upsert(route.copyWith(stops: entry.value));
        }
      }

      if (result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(const ShuttleStopPaymentPageResult(paid: true));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  List<PushRadiusMapPolyline> _mapPolylines() {
    final byRoute = <String, List<_ShuttlePayRow>>{};
    for (final row in _rows) {
      if (!_selectedStopIds.contains(row.stop.id)) continue;
      byRoute.putIfAbsent(row.routeId, () => []).add(row);
    }

    final polylines = <PushRadiusMapPolyline>[];
    for (final stops in byRoute.values) {
      stops.sort((a, b) => a.stopIndex.compareTo(b.stopIndex));
      if (stops.length < ShuttleRouteVisibility.polylineMinActivatedStops) {
        continue;
      }
      polylines.add(
        PushRadiusMapPolyline(
          points: stops.map((row) => row.stop.coordinate).toList(),
          color: stops.first.routeColor,
        ),
      );
    }
    return polylines;
  }

  List<PushRadiusMapOverlayPoint> _mapOverlays() {
    return [
      for (final row in _rows)
        PushRadiusMapOverlayPoint(
          coordinate: row.stop.coordinate,
          radiusMeters: 0,
          label: '${row.routeName} · ${row.stopIndex + 1}. ${row.stop.label}',
          pointIndex: row.stopIndex,
          draft: !row.stop.exposureActivated &&
              !_selectedStopIds.contains(row.stop.id),
        ),
    ];
  }

  GeoCoordinate _mapCenter() {
    final selected = _rows
        .where((row) => _selectedStopIds.contains(row.stop.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      if (_rows.isEmpty) return defaultPushMapCenter();
      return _rows.first.stop.coordinate;
    }
    var lat = 0.0;
    var lng = 0.0;
    for (final row in selected) {
      lat += row.stop.coordinate.latitude;
      lng += row.stop.coordinate.longitude;
    }
    final count = selected.length;
    return GeoCoordinate(latitude: lat / count, longitude: lng / count);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const accent = Color(0xFFE65100);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          '정류장 표시핀 결제',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text(
                    '등록된 정류장이 없습니다.\n먼저 정류장 표시핀을 추가해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : MapStackSplitLayout(
                  map: PushRadiusMapPicker(
                            key: ValueKey(
                              'shuttle_pay_${_rows.map((r) => r.stop.id).join('-')}_'
                              '${_selectedStopIds.join('-')}',
                            ),
                            center: _mapCenter(),
                            radiusMeters: 0,
                            hideZeroRadiusLabel: true,
                            centerEditable: false,
                            existingPoints: _mapOverlays(),
                            polylines: _mapPolylines(),
                            onCenterChanged: (_) {},
                          ),
                  bottom: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '정류장 표시핀',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SelectAllToggleBar(
                        allSelected: _chargeableRows.isNotEmpty &&
                            _chargeableRows.every(
                              (row) => _selectedStopIds.contains(row.stop.id),
                            ),
                        selectableCount: _chargeableRows.length,
                        selectedCount: _chargeableRows
                            .where(
                              (row) => _selectedStopIds.contains(row.stop.id),
                            )
                            .length,
                        onToggle: _toggleSelectAllChargeable,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final locked = _isStopLocked(row);
                          final selected = _selectedStopIds.contains(row.stop.id);
                          final highlighted = selected && !locked;
                          final remaining = _jobPost?.shuttleExposureExpiresAt ==
                                  null
                              ? null
                              : ShuttleExposurePolicy.remainingLabel(
                                  _jobPost!.shuttleExposureExpiresAt!,
                                );

                          return Material(
                            color: locked
                                ? AppColors.textSecondary.withValues(alpha: 0.08)
                                : highlighted
                                    ? row.routeColor.withValues(alpha: 0.14)
                                    : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: locked ? null : () => _toggleStop(row),
                              child: Container(
                                height: locked ? 52 : 46,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: locked
                                        ? AppColors.searchBarBorder
                                        : highlighted
                                            ? row.routeColor.withValues(alpha: 0.55)
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
                                        color: row.routeColor.withValues(
                                          alpha: locked
                                              ? 0.08
                                              : highlighted
                                                  ? 0.28
                                                  : 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${row.stopIndex + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: locked
                                              ? AppColors.textSecondary
                                                  .withValues(alpha: 0.55)
                                              : row.routeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${row.routeName} · ${row.stop.label}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: locked
                                                  ? AppColors.textSecondary
                                                      .withValues(alpha: 0.7)
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            locked
                                                ? '노출 중 · ${remaining ?? 'D+1 23:59:59까지'}'
                                                : selected
                                                    ? '선택됨'
                                                    : '탭하여 선택',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: locked
                                                  ? AppColors.textSecondary
                                                      .withValues(alpha: 0.8)
                                                  : selected
                                                      ? row.routeColor
                                                      : AppColors.textSecondary
                                                          .withValues(
                                                              alpha: 0.85),
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
                                          ? AppColors.textSecondary
                                              .withValues(alpha: 0.55)
                                          : selected
                                              ? row.routeColor
                                              : AppColors.textSecondary
                                                  .withValues(alpha: 0.55),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_selectedCount > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '총 ${PushPackageCatalog.formatKrw(_checkoutTotalKrw)}원',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (_selectedCount > 0) const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _canCheckout ? _checkout : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              disabledBackgroundColor:
                                  accent.withValues(alpha: 0.35),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _paying
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _checkoutButtonLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          if (!_canCheckout && !_paying) ...[
                            const SizedBox(height: 8),
                            Text(
                              '결제할 정류장을 탭해 선택해 주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
