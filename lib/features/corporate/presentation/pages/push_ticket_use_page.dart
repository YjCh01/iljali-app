import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/core/widgets/map_form_split_layout.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';
import 'package:map/features/corporate/presentation/widgets/select_all_toggle_bar.dart';

class PushTicketUseArgs {
  const PushTicketUseArgs({
    required this.jobTitle,
    this.jobPostId,
    this.notificationSettings,
    this.shuttleRouteId,
    this.hasShuttleRouteOverlay = false,
  });

  final String jobTitle;
  final String? jobPostId;
  final JobPostNotificationSettings? notificationSettings;
  final String? shuttleRouteId;
  final bool hasShuttleRouteOverlay;
}

/// PUSH 이용권 사용 — 알림핀·정류장 선택 후 발송
class PushTicketUsePage extends StatefulWidget {
  const PushTicketUsePage({super.key, required this.args});

  final PushTicketUseArgs args;

  @override
  State<PushTicketUsePage> createState() => _PushTicketUsePageState();
}

class _PushTicketUsePageState extends State<PushTicketUsePage> {
  List<CommuteRoute> _routes = [];
  bool _loading = true;
  bool _sending = false;
  int _pushCredits = 0;
  bool _jobPinsExpanded = true;
  final _selectedJobPinIds = <String>{};
  final _selectedShuttleStopIds = <String>{};
  final _expandedRouteIds = <String>{};

  List<PushNotificationBasePoint> get _points =>
      widget.args.notificationSettings?.basePoints ?? const [];

  List<PushNotificationBasePoint> get _jobPins => [
        for (var i = 1; i < _points.length; i++) _points[i],
      ];

  int get _selectedCount =>
      _selectedJobPinIds.length + _selectedShuttleStopIds.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final wallet = await PushWalletService().loadWallet(profile);
    final repo = await CommuteRouteRepository.create();
    final routes = await repo.loadForCompany(profile.companyKey);

    final preferred = widget.args.shuttleRouteId?.trim();
    final expanded = <String>{};
    if (preferred != null && preferred.isNotEmpty) {
      expanded.add(preferred);
    } else if (routes.isNotEmpty) {
      expanded.add(routes.first.id);
    }

    if (!mounted) return;
    setState(() {
      _pushCredits = wallet.pushTicketCredits;
      _routes = routes;
      _expandedRouteIds
        ..clear()
        ..addAll(expanded);
      _loading = false;
    });
  }

  CorporateJobPost get _draftPost => CorporateJobPost(
        id: widget.args.jobPostId ??
            'draft_${DateTime.now().millisecondsSinceEpoch}',
        title: widget.args.jobTitle,
        warehouseName: '',
        hourlyWage: '',
        workSchedule: '',
        summary: '',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime.now(),
        notificationSettings: widget.args.notificationSettings,
        commuteRouteId: widget.args.shuttleRouteId,
        hasShuttleRouteOverlay: widget.args.hasShuttleRouteOverlay,
      );

  List<PushDispatchTarget> _buildTargets() {
    final targets = <PushDispatchTarget>[];
    final settings = widget.args.notificationSettings;

    if (settings != null) {
      for (var i = 0; i < settings.basePoints.length; i++) {
        if (!PushWalletCreditPolicy.isRecruitmentZoneIndex(i)) continue;
        final point = settings.basePoints[i];
        if (!point.exposureActivated) continue;
        targets.add(
          PushDispatchTarget(
            id: 'pin_${point.id}',
            kind: PushDispatchTargetKind.notificationPin,
            title: ExposurePointLabels.title(i),
            subtitle: PushDispatchTargetKind.notificationPin.iconHint,
            coordinate: point.coordinate,
            radiusMeters: point.radiusMeters > 0
                ? point.radiusMeters
                : PushPackageCatalog.packagePushRadiusM,
            basePointId: point.id,
            exposureActivated: point.exposureActivated,
          ),
        );
      }
    }

    for (final route in _routes) {
      for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
        if (!stop.exposureActivated) continue;
        targets.add(
          PushDispatchTarget(
            id: 'stop_${stop.id}',
            kind: PushDispatchTargetKind.shuttleStop,
            title: stop.label,
            subtitle: '${route.routeName} · 정류장',
            coordinate: stop.coordinate,
            radiusMeters: PushPackageCatalog.packagePushRadiusM,
            shuttleStopId: stop.id,
            routeName: route.routeName,
            routeId: route.id,
            exposureActivated: stop.exposureActivated,
          ),
        );
      }
    }

    return targets;
  }

  List<PushDispatchTarget> get _selectedTargets {
    final targets = _buildTargets();
    return [
      for (final target in targets)
        if ((target.kind == PushDispatchTargetKind.notificationPin &&
                _selectedJobPinIds.contains(target.basePointId)) ||
            (target.kind == PushDispatchTargetKind.shuttleStop &&
                _selectedShuttleStopIds.contains(target.shuttleStopId)))
          target,
    ];
  }

  String? _blockReason(PushDispatchTarget target) =>
      ExposureSlotPolicy.pushTicketBlockReason(
        post: _draftPost,
        target: target,
        settings: widget.args.notificationSettings,
      );

  void _toggleJobPin(PushNotificationBasePoint pin) {
    if (!pin.exposureActivated || _blockReasonForPin(pin) != null) return;
    setState(() {
      if (_selectedJobPinIds.contains(pin.id)) {
        _selectedJobPinIds.remove(pin.id);
      } else {
        _selectedJobPinIds.add(pin.id);
      }
    });
  }

  void _toggleShuttleStop(CommuteRouteStop stop) {
    if (!stop.exposureActivated) return;
    setState(() {
      if (_selectedShuttleStopIds.contains(stop.id)) {
        _selectedShuttleStopIds.remove(stop.id);
      } else {
        _selectedShuttleStopIds.add(stop.id);
        for (final route in _routes) {
          if (route.stops.any((s) => s.id == stop.id)) {
            _expandedRouteIds.add(route.id);
            break;
          }
        }
      }
    });
  }

  String? _blockReasonForPin(PushNotificationBasePoint pin) {
    final index = _points.indexWhere((p) => p.id == pin.id);
    if (index < 0) return null;
    final target = PushDispatchTarget(
      id: 'pin_${pin.id}',
      kind: PushDispatchTargetKind.notificationPin,
      title: ExposurePointLabels.title(index),
      subtitle: '',
      coordinate: pin.coordinate,
      radiusMeters: pin.radiusMeters,
      basePointId: pin.id,
      exposureActivated: pin.exposureActivated,
    );
    return _blockReason(target);
  }

  List<PushRadiusMapOverlayPoint> _mapOverlays() {
    final overlays = <PushRadiusMapOverlayPoint>[];
    for (var i = 1; i < _points.length; i++) {
      final point = _points[i];
      if (!point.exposureActivated) continue;
      final selected = _selectedJobPinIds.contains(point.id);
      overlays.add(
        PushRadiusMapOverlayPoint(
          coordinate: point.coordinate,
          radiusMeters: point.radiusTier.radiusMeters,
          label: ExposurePointLabels.title(i),
          pointIndex: i,
          draft: !selected,
          visualTheme: PushCreditVisualTheme.forRecruitPoint(i),
        ),
      );
    }
    for (final route in _routes) {
      for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
        if (!stop.exposureActivated) continue;
        final selected = _selectedShuttleStopIds.contains(stop.id);
        overlays.add(
          PushRadiusMapOverlayPoint(
            coordinate: stop.coordinate,
            radiusMeters: 0,
            label: stop.label,
            pointIndex: 100 + overlays.length,
            draft: !selected,
          ),
        );
      }
    }
    return overlays;
  }

  GeoCoordinate _mapCenter() {
    final selected = _selectedTargets;
    if (selected.isNotEmpty) return selected.first.coordinate;
    for (final pin in _jobPins) {
      if (pin.exposureActivated) return pin.coordinate;
    }
    for (final route in _routes) {
      for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
        if (stop.exposureActivated) return stop.coordinate;
      }
    }
    if (_points.length > 1) return _points[1].coordinate;
    if (_points.isNotEmpty) return _points.first.coordinate;
    return defaultPushMapCenter();
  }

  List<CommuteRoute> get _routesWithStops => _routes
      .where(
        (route) =>
            ShuttleRouteStopPolicy.pushEligibleStops(route.stops).isNotEmpty,
      )
      .toList(growable: false);

  int _selectedCountInRoute(String routeId) {
    for (final route in _routes) {
      if (route.id != routeId) continue;
      return ShuttleRouteStopPolicy.pushEligibleStops(route.stops)
          .where((stop) => _selectedShuttleStopIds.contains(stop.id))
          .length;
    }
    return 0;
  }

  List<PushNotificationBasePoint> _selectableJobPins(
    List<PushNotificationBasePoint> jobPins,
  ) =>
      jobPins
          .where(
            (pin) =>
                pin.exposureActivated && _blockReasonForPin(pin) == null,
          )
          .toList();

  List<CommuteRouteStop> _selectableStopsInRoute(CommuteRoute route) =>
      ShuttleRouteStopPolicy.pushEligibleStops(route.stops)
          .where(
            (stop) =>
                stop.exposureActivated && _blockReasonForStop(stop) == null,
          )
          .toList();

  void _toggleSelectAllJobPins(List<PushNotificationBasePoint> jobPins) {
    final selectable = _selectableJobPins(jobPins);
    if (selectable.isEmpty) return;
    final ids = selectable.map((pin) => pin.id).toSet();
    final allSelected = ids.every(_selectedJobPinIds.contains);
    setState(() {
      if (allSelected) {
        _selectedJobPinIds.removeAll(ids);
      } else {
        _selectedJobPinIds.addAll(ids);
      }
    });
  }

  void _toggleSelectAllInRoute(CommuteRoute route) {
    final selectable = _selectableStopsInRoute(route);
    if (selectable.isEmpty) return;
    final ids = selectable.map((stop) => stop.id).toSet();
    final allSelected = ids.every(_selectedShuttleStopIds.contains);
    setState(() {
      if (allSelected) {
        _selectedShuttleStopIds.removeAll(ids);
      } else {
        _selectedShuttleStopIds.addAll(ids);
        _expandedRouteIds.add(route.id);
      }
    });
  }

  void _toggleSelectAllTargets({
    required List<PushNotificationBasePoint> jobPins,
    required List<CommuteRoute> routesWithStops,
  }) {
    final jobIds = _selectableJobPins(jobPins).map((pin) => pin.id).toSet();
    final stopIds = <String>{};
    for (final route in routesWithStops) {
      stopIds.addAll(
        _selectableStopsInRoute(route).map((stop) => stop.id),
      );
    }
    if (jobIds.isEmpty && stopIds.isEmpty) return;
    final allSelected = jobIds.every(_selectedJobPinIds.contains) &&
        stopIds.every(_selectedShuttleStopIds.contains);
    setState(() {
      if (allSelected) {
        _selectedJobPinIds.removeAll(jobIds);
        _selectedShuttleStopIds.removeAll(stopIds);
      } else {
        _selectedJobPinIds.addAll(jobIds);
        _selectedShuttleStopIds.addAll(stopIds);
        _expandedRouteIds.addAll(routesWithStops.map((route) => route.id));
      }
    });
  }

  bool get _canUse =>
      !_sending &&
      _pushCredits > 0 &&
      _selectedCount > 0 &&
      _selectedCount <= _pushCredits;

  Future<void> _sendPush() async {
    if (!_canUse) return;
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    final selected = _selectedTargets;
    if (selected.isEmpty) return;

    setState(() => _sending = true);

    final prepared = selected.length == 1
        ? await PushDispatchService().prepareTargetedDispatch(
            context: context,
            profile: profile,
            post: _draftPost,
            target: selected.first,
            paymentMode: PushTargetPaymentMode.walletCredit,
          )
        : await PushDispatchService().prepareBatchTargetedDispatch(
            context: context,
            profile: profile,
            post: _draftPost,
            targets: selected,
            paymentMode: PushTargetPaymentMode.walletCredit,
          );

    if (!mounted) return;
    setState(() => _sending = false);
    if (prepared == null) return;

    final targetLabel = selected.map((t) => t.title).join(' · ');
    await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushDispatch,
      arguments: PushDispatchArgs(
        radiusTier: prepared.radiusTier,
        recruitmentSlotCount: selected.length,
        jobPostId: _draftPost.id,
        jobTitle: widget.args.jobTitle,
        companyName: profile.companyName,
        targetLabel: targetLabel,
        targetKind: selected.first.kind,
        recruitmentTargets: [
          for (final target in selected)
            RecruitmentPushTargetArgs(
              latitude: target.coordinate.latitude,
              longitude: target.coordinate.longitude,
              radiusMeters: target.radiusMeters,
              label: target.title,
            ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _toggleRouteExpanded(String routeId, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedRouteIds.add(routeId);
      } else {
        _expandedRouteIds.remove(routeId);
      }
    });
  }

  Widget _buildPinRow({
    required String title,
    required String subtitle,
    required bool activated,
    required bool selected,
    required Color accent,
    required VoidCallback? onToggle,
  }) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.06)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: onToggle == null ? null : (_) => onToggle(),
                activeColor: accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: activated
                            ? accent
                            : AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionSection({
    required String title,
    required IconData icon,
    required Color accent,
    required int selectedCount,
    required int totalCount,
    required bool expanded,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    if (totalCount <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: expanded,
            onExpansionChanged: onExpansionChanged,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            leading: Icon(icon, size: 20, color: accent),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              selectedCount > 0
                  ? '$totalCount개 중 $selectedCount개 선택'
                  : '$totalCount개 · 선택해 주세요',
              style: TextStyle(
                fontSize: 11,
                color: selectedCount > 0
                    ? accent
                    : AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteExpansion(CommuteRoute route) {
    final pushEligibleStops =
        ShuttleRouteStopPolicy.pushEligibleStops(route.stops).toList();
    final activatedStops =
        pushEligibleStops.where((stop) => stop.exposureActivated).toList();
    if (activatedStops.isEmpty && pushEligibleStops.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedInRoute = _selectedCountInRoute(route.id);
    final accent = ShuttleRouteColorUtils.parseHex(route.overlayColorHex);
    final expanded = _expandedRouteIds.contains(route.id);
    final stopCount = pushEligibleStops.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('route_${route.id}_$expanded'),
            initiallyExpanded: expanded,
            onExpansionChanged: (value) => _toggleRouteExpanded(route.id, value),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            leading: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            title: Text(
              route.routeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              selectedInRoute > 0
                  ? '정류장 $stopCount개 · 선택 $selectedInRoute개'
                  : '정류장 $stopCount개',
              style: TextStyle(
                fontSize: 11,
                color: selectedInRoute > 0
                    ? accent
                    : AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            children: pushEligibleStops.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '발송 가능한 정류장 표시핀이 없습니다.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ]
                : [
                    SelectAllToggleBar(
                      allSelected: _selectableStopsInRoute(route).isNotEmpty &&
                          _selectableStopsInRoute(route)
                              .every((stop) => _selectedShuttleStopIds.contains(stop.id)),
                      selectableCount: _selectableStopsInRoute(route).length,
                      selectedCount: selectedInRoute,
                      activeColor: accent,
                      onToggle: () => _toggleSelectAllInRoute(route),
                    ),
                    for (final stop in pushEligibleStops)
                      _buildPinRow(
                        title: stop.label,
                        subtitle: _blockReasonForStop(stop) ??
                            (stop.exposureActivated
                                ? '지도 노출 중'
                                : '노출 결제 필요'),
                        activated: stop.exposureActivated,
                        selected: _selectedShuttleStopIds.contains(stop.id),
                        accent: accent,
                        onToggle: stop.exposureActivated &&
                                _blockReasonForStop(stop) == null
                            ? () => _toggleShuttleStop(stop)
                            : null,
                      ),
                  ],
          ),
        ),
      ),
    );
  }

  String? _blockReasonForStop(CommuteRouteStop stop) {
    for (final route in _routes) {
      if (!route.stops.any((s) => s.id == stop.id)) continue;
      final target = PushDispatchTarget(
        id: 'stop_${stop.id}',
        kind: PushDispatchTargetKind.shuttleStop,
        title: stop.label,
        subtitle: '',
        coordinate: stop.coordinate,
        radiusMeters: PushPackageCatalog.packagePushRadiusM,
        shuttleStopId: stop.id,
        routeName: route.routeName,
        routeId: route.id,
        exposureActivated: stop.exposureActivated,
      );
      return _blockReason(target);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final jobPins = _jobPins;
    final activatedJobPins =
        jobPins.where((pin) => pin.exposureActivated).toList();
    final routesWithStops = _routesWithStops;
    final hasActivatedShuttle = routesWithStops.any(
      (route) => ShuttleRouteStopPolicy.pushEligibleStops(route.stops)
          .any((stop) => stop.exposureActivated),
    );
    final hasAnyTarget = activatedJobPins.isNotEmpty || hasActivatedShuttle;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selectableJobPins = _selectableJobPins(jobPins);
    final selectableShuttleCount = routesWithStops.fold<int>(
      0,
      (sum, route) => sum + _selectableStopsInRoute(route).length,
    );
    final totalSelectable = selectableJobPins.length + selectableShuttleCount;
    final totalSelectedInScope =
        _selectedJobPinIds.length + _selectedShuttleStopIds.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text(
          'PUSH 이용권 사용',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasAnyTarget
              ? Center(
                  child: Text(
                    '노출 활성화된 일자리 알림핀·정류장 표시핀이 없습니다.\n'
                    '먼저 알림핀·정류장 결제로 노출을 활성화해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : MapStackSplitLayout(
                  topBanner: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '노출 상태가 종료된 알림핀/표시핀에는 PUSH 알림을 발송할 수 없습니다. '
                            '아래에서 노출 중인 위치만 선택할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'PUSH를 보낼 위치를 체크하세요. 선택한 개수만큼 이용권이 차감됩니다.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: AppColors.textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  map: PushRadiusMapPicker(
                            key: ValueKey(
                              'push_use_${_selectedJobPinIds.join('-')}_'
                              '${_selectedShuttleStopIds.join('-')}',
                            ),
                            center: _mapCenter(),
                            radiusMeters: 0,
                            hideZeroRadiusLabel: true,
                            centerEditable: false,
                            existingPoints: _mapOverlays(),
                            onCenterChanged: (_) {},
                            viewportSessionKey:
                                MapViewportSessionKeys.pushTicketUse,
                          ),
                  bottom: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (totalSelectable > 0)
                            SelectAllToggleBar(
                              allSelected: totalSelectable > 0 &&
                                  selectableJobPins.every(
                                    (pin) =>
                                        _selectedJobPinIds.contains(pin.id),
                                  ) &&
                                  routesWithStops.every(
                                    (route) => _selectableStopsInRoute(route)
                                        .every(
                                      (stop) => _selectedShuttleStopIds
                                          .contains(stop.id),
                                    ),
                                  ),
                              selectableCount: totalSelectable,
                              selectedCount: totalSelectedInScope,
                              onToggle: () => _toggleSelectAllTargets(
                                jobPins: jobPins,
                                routesWithStops: routesWithStops,
                              ),
                              padding: const EdgeInsets.only(bottom: 8),
                            ),
                          _buildExpansionSection(
                            title: '일자리 알림핀',
                            icon: Icons.push_pin_outlined,
                            accent: AppColors.primary,
                            selectedCount: _selectedJobPinIds.length,
                            totalCount: jobPins.length,
                            expanded: _jobPinsExpanded,
                            onExpansionChanged: (value) =>
                                setState(() => _jobPinsExpanded = value),
                            children: jobPins.isEmpty
                                ? [
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        '저장된 일자리 알림핀이 없습니다.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ),
                                  ]
                                : [
                                    SelectAllToggleBar(
                                      allSelected: selectableJobPins.isNotEmpty &&
                                          selectableJobPins.every(
                                            (pin) => _selectedJobPinIds
                                                .contains(pin.id),
                                          ),
                                      selectableCount: selectableJobPins.length,
                                      selectedCount: _selectedJobPinIds.length,
                                      onToggle: () =>
                                          _toggleSelectAllJobPins(jobPins),
                                    ),
                                    for (var i = 0; i < jobPins.length; i++)
                                      _buildPinRow(
                                        title: ExposurePointLabels.title(i + 1),
                                        subtitle: _blockReasonForPin(
                                              jobPins[i],
                                            ) ??
                                            (jobPins[i].exposureActivated
                                                ? '지도 노출 중'
                                                : '노출 결제 필요'),
                                        activated: jobPins[i].exposureActivated,
                                        selected: _selectedJobPinIds
                                            .contains(jobPins[i].id),
                                        accent: PushCreditVisualTheme
                                            .forRecruitPoint(i + 1)
                                            .accent,
                                        onToggle: jobPins[i].exposureActivated &&
                                                _blockReasonForPin(jobPins[i]) ==
                                                    null
                                            ? () => _toggleJobPin(jobPins[i])
                                            : null,
                                      ),
                                  ],
                          ),
                          if (routesWithStops.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '정류장 표시핀',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary
                                      .withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                            ...routesWithStops.map(_buildRouteExpansion),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '보유 PUSH 이용권 $_pushCredits회',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withValues(alpha: 0.95),
                            ),
                          ),
                          if (_selectedCount > _pushCredits) ...[
                            const SizedBox(height: 4),
                            Text(
                              '선택 $_selectedCount곳 — 보유 이용권이 부족합니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _canUse ? _sendPush : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '사용하기',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
