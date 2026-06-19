import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/usecases/search_workplace_address_usecase.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/features/corporate/presentation/widgets/exposure_zone_add_row.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_service_action_style.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_route_color_picker.dart';
import 'package:map/features/corporate/domain/utils/recruitment_pin_link_factory.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

/// PUSH 알림 거점 설정 — 반경(플랜별 거리) + 지정 포인트
class PushNotificationBasePointPage extends StatefulWidget {
  const PushNotificationBasePointPage({
    super.key,
    this.initialSettings,
    this.workplaceHint,
  });

  final JobPostNotificationSettings? initialSettings;
  final WorkplaceAddress? workplaceHint;

  @override
  State<PushNotificationBasePointPage> createState() =>
      _PushNotificationBasePointPageState();
}

class _PushNotificationBasePointPageState
    extends State<PushNotificationBasePointPage> with WidgetsBindingObserver {
  static const _previewRecruitmentPinCap = 10;

  final _search = SearchWorkplaceAddressUseCase();
  final _searchController = TextEditingController();

  late GeoCoordinate _center;
  late PushRadiusTier _radiusTier;
  late DesignatedPointTier _pointTier;
  late List<PushNotificationBasePoint> _points;
  int _activePointIndex = 0;
  String _addressLabel = '';
  List<WorkplaceAddress> _searchResults = [];
  bool _searching = false;
  bool _walletReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      clearSnackBarQueue(context);
    });
    final settings = widget.initialSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      _points = List.from(settings.basePoints);
      _pointTier = settings.designatedPointTier;
      _activePointIndex = 0;
      final active = _points.first;
      _center = active.coordinate;
      _addressLabel = active.addressLabel;
      _radiusTier = active.radiusTier;
    } else if (widget.workplaceHint != null) {
      final hint = widget.workplaceHint!;
      _center = hint.coordinate ?? defaultPushMapCenter();
      _addressLabel = hint.roadAddress;
      _radiusTier = PushRadiusTier.standardFree1km;
      _pointTier = DesignatedPointTier.onePoint;
      _points = [
        PushNotificationBasePoint(
          id: 'base_primary',
          coordinate: _center,
          addressLabel: _addressLabel,
          radiusTier: _radiusTier,
          isPrimary: true,
        ),
      ];
    } else {
      _center = defaultPushMapCenter();
      _addressLabel = '강남·역삼 일대';
      _radiusTier = PushRadiusTier.standardFree1km;
      _pointTier = DesignatedPointTier.onePoint;
      _points = [
        PushNotificationBasePoint(
          id: 'base_primary',
          coordinate: _center,
          addressLabel: _addressLabel,
          radiusTier: _radiusTier,
          isPrimary: true,
        ),
      ];
    }
    _searchController.text = _addressLabel;
    _clampAllToPlan();
    _ensureWalletLoaded();
  }

  Future<void> _ensureWalletLoaded() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      if (mounted) setState(() => _walletReady = true);
      return;
    }
    await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() {
      _walletReady = true;
      _clampAllToPlan();
    });
  }

  void _clampAllToPlan() {
    _pointTier = PushPlanEnforcement.maxPointTier;
    _radiusTier = PushPlanEnforcement.clampRadius(_radiusTier);
    final allowedKm = PushPlanEnforcement.allowedSliderKmSteps;
    if (allowedKm.isNotEmpty &&
        !allowedKm.contains(_radiusTier.radiusKm)) {
      _radiusTier = PushRadiusOptions.fromKm(allowedKm.last);
    }
    final hardCap = _previewRecruitmentPinCap + PushPackageCatalog.baseLocationSlots;
    while (_points.length > hardCap) {
      _points.removeLast();
    }
    for (var i = 0; i < _points.length; i++) {
      final clamped = PushPlanEnforcement.clampRadius(_points[i].radiusTier);
      if (_points[i].radiusTier != clamped) {
        _points[i] = _points[i].copyWith(radiusTier: clamped);
      }
    }
    if (_activePointIndex >= _points.length) {
      _activePointIndex = _points.length - 1;
    }
  }

  /// 일자리 알림핀 구매 후 반경·거점 한도를 지갑 기준으로 일괄 반영
  void _applyWalletDefaults() {
    _pointTier = PushPlanEnforcement.maxPointTier;
    _radiusTier = PushPlanEnforcement.defaultRadiusTier;
    for (var i = 0; i < _points.length; i++) {
      _points[i] = _points[i].copyWith(radiusTier: _radiusTier);
    }
    while (_points.length > _maxPoints) {
      _points.removeLast();
    }
    if (_activePointIndex >= _points.length) {
      _activePointIndex = _points.length - 1;
    }
    _loadActivePointState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPlanLimitsAsync();
    }
  }

  void _refreshPlanLimits({bool afterUpgrade = false}) {
    setState(() {
      _clampAllToPlan();
      if (afterUpgrade) {
        _applyWalletDefaults();
      } else {
        _loadActivePointState();
      }
    });
  }

  Future<void> _refreshPlanLimitsAsync({bool afterUpgrade = false}) async {
    await _ensureWalletLoaded();
    if (!mounted) return;
    _refreshPlanLimits(afterUpgrade: afterUpgrade);
  }

  void _loadActivePointState() {
    if (_points.isEmpty) return;
    if (_activePointIndex >= _points.length) {
      _activePointIndex = _points.length - 1;
    }
    final point = _points[_activePointIndex];
    _center = point.coordinate;
    _addressLabel = point.addressLabel;
    _radiusTier = point.radiusTier;
    _searchController.text = point.addressLabel;
  }

  int get _maxPoints {
    final wallet =
        AuthSession.instance.currentUser?.corporateProfile?.pushWallet ??
            const EmployerPushWallet();
    return PushWalletCreditPolicy.effectiveMaxExposurePoints(
      wallet: wallet,
      currentPointsLength: _points.length,
    );
  }

  int get _remainingAddSlots {
    return PushWalletCreditPolicy.configurePreviewRemainingAddSlots(
      pointsLength: _points.length,
      previewRecruitmentPinCap: _previewRecruitmentPinCap,
    );
  }

  /// 근무지(0번)는 고정 — 노출 중 알림핀은 위치 수정 불가
  bool get _canEditActivePointLocation =>
      _activePointIndex > 0 && !_isPinExposureLocked(_activePointIndex);

  bool _isPinExposureLocked(int index) {
    if (index <= 0 || index >= _points.length) return false;
    return _points[index].isExposureLocked;
  }

  /// [_addPoint]와 동일 — setState 밖에서 호출 가능
  void _addPointInternal() {
    if (_remainingAddSlots <= 0) return;
    final base = _points.first.coordinate;
    final n = _points.length;
    final angle = (n - 1) * 0.9;
    final dist = 0.0035 + n * 0.0012;
    final newPoint = PushNotificationBasePoint(
      id: 'base_${DateTime.now().millisecondsSinceEpoch}',
      coordinate: GeoCoordinate(
        latitude: base.latitude + dist * math.cos(angle),
        longitude: base.longitude + dist * math.sin(angle),
      ),
      addressLabel: ExposurePointLabels.title(n),
      radiusTier: _radiusTier,
      isPrimary: false,
      isPremiumSlot: true,
    );
    _points = [..._points, newPoint];
    _activePointIndex = _points.length - 1;
    _loadActivePointState();
  }

  void _syncActivePointToList() {
    if (_points.isEmpty) return;
    final tier = _activePointIndex == 0
        ? PushRadiusTier.standardFree1km
        : _radiusTier;
    _points[_activePointIndex] = _points[_activePointIndex].copyWith(
      coordinate: _center,
      addressLabel: _addressLabel,
      radiusTier: tier,
    );
  }

  Future<void> _runAddressSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final result = await _search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = result.addresses;
      _searching = false;
    });
  }

  void _selectSearchResult(WorkplaceAddress address) {
    final coordinate = address.coordinate ?? defaultPushMapCenter();
    setState(() {
      _center = coordinate;
      _addressLabel = address.roadAddress;
      _searchController.text = address.roadAddress;
      _searchResults = [];
      _syncActivePointToList();
    });
  }

  void _selectRadius(PushRadiusTier tier) {
    if (_activePointIndex == 0) return;
    if (!PushPlanEnforcement.isRadiusAllowed(tier)) {
      _showPlanUpsell('이 반경은 일자리 알림핀에서 이용할 수 있습니다.');
      return;
    }
    setState(() {
      _radiusTier = tier;
      _syncActivePointToList();
    });
  }

  Future<void> _openPushPackageShop() async {
    clearSnackBarQueue(context);
    await Navigator.of(context).pushNamed<bool?>(
      AppRoutes.corporatePushPackageShop,
    );
    if (!mounted) return;
    clearSnackBarQueue(context);
    await _refreshPlanLimitsAsync();
  }

  void _selectPointTab(int index) {
    if (index < 0 || index >= _points.length) return;
    _syncActivePointToList();
    setState(() {
      _activePointIndex = index;
      _loadActivePointState();
    });
  }

  void _addPoint() {
    if (_remainingAddSlots <= 0) {
      unawaited(_showPlanUpsell(
        '일자리 알림핀은 최대 $_previewRecruitmentPinCap개까지 미리 배치할 수 있습니다.',
      ));
      return;
    }
    _syncActivePointToList();
    setState(_addPointInternal);
  }

  void _removePoint(int index) {
    if (index <= 0 || index >= _points.length) return;
    unawaited(_removePointWithRefund(index));
  }

  Future<void> _removePointWithRefund(int index) async {
    if (index <= 0 || index >= _points.length) return;
    if (_isPinExposureLocked(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('노출 중인 알림핀은 삭제할 수 없습니다. 노출 종료 후 다시 시도해 주세요.'),
        ),
      );
      return;
    }
    _syncActivePointToList();
    final point = _points[index];
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile != null && point.exposureActivated) {
      await PushWalletService().refundRecruitmentCredit(profile);
      await _ensureWalletLoaded();
    }
    if (!mounted) return;
    setState(() {
      _points.removeAt(index);
      if (_activePointIndex >= _points.length) {
        _activePointIndex = _points.length - 1;
      } else if (_activePointIndex > index) {
        _activePointIndex--;
      }
      _loadActivePointState();
    });
  }

  void _onAddZoneFromRow() {
    _addPoint();
  }

  void _confirm() {
    _syncActivePointToList();
    _clampAllToPlan();
    final unpaidCount = [
      for (var i = 1; i < _points.length; i++)
        if (!_points[i].isExposureLocked) i,
    ].length;
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pop(
      JobPostNotificationSettings(
        basePoints: List.unmodifiable(_points),
        maxBasePointsAllowed: _points.length,
        paymentCompleted: unpaidCount == 0 && _points.length > 1,
        designatedPointTier: _pointTier,
        spotPaymentCompleted: unpaidCount == 0 && _points.length > 1,
      ),
    );
  }

  Future<void> _showPlanUpsell(String message) async {
    final goShop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일자리 알림핀'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('이용권 충전'),
          ),
        ],
      ),
    );
    if (goShop != true || !mounted) return;
    await _openPushPackageShop();
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme =
        PushCreditVisualTheme.forRecruitPoint(_activePointIndex);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('일자리 알림핀 설정'),
      ),
      body: !_walletReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) 지도 + 반경 슬라이더 — 항상 최상단
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PushRadiusMapPicker(
                    key: ValueKey(
                      'map_${_activePointIndex}_${_points.length}_'
                      '${_points.map((p) => p.id).join('-')}',
                    ),
                    center: _center,
                    radiusMeters: _radiusTier.radiusMeters,
                    centerEditable: _canEditActivePointLocation,
                    existingPoints: _existingMapOverlays,
                    activePointLabel: _activeMapLabel,
                    visualTheme: activeTheme,
                    onExistingPointTap: _points.length > 1
                        ? _selectPointTab
                        : null,
                    onCenterChanged: (coordinate) {
                      if (!_canEditActivePointLocation) return;
                      setState(() {
                        _center = coordinate;
                        _syncActivePointToList();
                      });
                    },
                    maxZoom: 21,
                    viewportSessionKey: MapViewportSessionKeys.pushBasePoint(
                      _points[_activePointIndex].id,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ExposureZoneRowList(
                    points: _points,
                    activeIndex: _activePointIndex,
                    remainingAddSlots: _remainingAddSlots,
                    onSelect: _selectPointTab,
                    onRemove: _removePoint,
                    onAdd: _onAddZoneFromRow,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _pointTabLabel(_activePointIndex),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: activeTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (ExposurePointLabels
                      .zoneRowSubtitle(_activePointIndex)
                      .isNotEmpty)
                    Text(
                      ExposurePointLabels.zoneRowSubtitle(_activePointIndex),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  if (_activePointIndex > 0 && _isPinExposureLocked(_activePointIndex)) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.searchBarBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_clock_outlined,
                            size: 18,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '노출 중인 알림핀은 위치를 수정할 수 없습니다. '
                              '${_points[_activePointIndex].exposureExpiresAt == null ? 'D+1 23:59:59까지' : ShuttleExposurePolicy.remainingLabel(_points[_activePointIndex].exposureExpiresAt!)} · 새 핀만 추가 가능',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_activePointIndex > 0) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '알림핀 색상',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShuttleRouteColorPicker(
                      colorHex: (_points[_activePointIndex].pinColorHex ??
                              '#9B86F0')
                          .toUpperCase(),
                      onChanged: (hex) {
                        setState(() {
                          _points = [
                            for (var i = 0; i < _points.length; i++)
                              if (i == _activePointIndex)
                                _points[i].copyWith(pinColorHex: hex)
                              else
                                _points[i],
                          ];
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '근무지와 점선으로 연결됩니다 · 1개부터 표시',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PushRadiusKmSlider(
                      selectedKm: _radiusTier.radiusKm,
                      allowedKmSteps: PushPlanEnforcement.allowedSliderKmSteps,
                      accentColor: activeTheme.accent,
                      suppressCenterLabel: true,
                      onChanged: (km) =>
                          _selectRadius(PushRadiusOptions.fromKm(km)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_canEditActivePointLocation) ...[
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _runAddressSearch,
                      onChanged: _runAddressSearch,
                      decoration: InputDecoration(
                        hintText:
                            '${_pointTabLabel(_activePointIndex)} — 도로명·동 검색',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: AppColors.searchBarBorder),
                        ),
                      ),
                    ),
                    if (_searching) ...[
                      const SizedBox(height: 4),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            return ActionChip(
                              label: Text(
                                item.dongName ?? item.roadAddress,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => _selectSearchResult(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ] else if (_activePointIndex == 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.searchBarBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 18,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _addressLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _confirm,
                    style: CorporateServiceActionStyle.setupFilled(),
                    child: const Text(
                      '설정 완료',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PushRadiusMapOverlayPoint> get _existingMapOverlays {
    return [
      for (var i = 0; i < _points.length; i++)
        if (i != _activePointIndex)
          PushRadiusMapOverlayPoint(
            coordinate: _points[i].coordinate,
            radiusMeters: _points[i].radiusTier.radiusMeters,
            label: _pointTabLabel(i),
            pointIndex: i,
            visualTheme: i == 0
                ? PushCreditVisualTheme.forRecruitPoint(i)
                : PushCreditVisualTheme.withAccent(_points[i].resolvedPinColor),
          ),
    ];
  }

  String? get _activeMapLabel {
    if (_points.length <= 1) return null;
    return _pointTabLabel(_activePointIndex);
  }

  String _pointTabLabel(int index) => ExposurePointLabels.title(index);
}

class _ExposureZoneRowList extends StatefulWidget {
  const _ExposureZoneRowList({
    required this.points,
    required this.activeIndex,
    required this.remainingAddSlots,
    required this.onSelect,
    required this.onRemove,
    required this.onAdd,
  });

  static const int maxVisibleRows = 4;
  static const double rowHeight = 46;
  static const double listRadius = 12;

  final List<PushNotificationBasePoint> points;
  final int activeIndex;
  final int remainingAddSlots;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  @override
  State<_ExposureZoneRowList> createState() => _ExposureZoneRowListState();
}

class _ExposureZoneRowListState extends State<_ExposureZoneRowList> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ExposureZoneRowList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.length > oldWidget.points.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollHeight = (widget.points.length.clamp(1, _ExposureZoneRowList.maxVisibleRows) *
            _ExposureZoneRowList.rowHeight)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '설정 목록',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_ExposureZoneRowList.listRadius),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: scrollHeight,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.hardEdge,
                  physics: widget.points.length > _ExposureZoneRowList.maxVisibleRows
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: widget.points.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.searchBarBorder.withValues(alpha: 0.85),
                  ),
                  itemBuilder: (context, index) {
                    final point = widget.points[index];
                    final locked = index > 0 && point.isExposureLocked;
                    return _ExposureZoneRow(
                      index: index,
                      point: point,
                      selected: index == widget.activeIndex,
                      isFirst: index == 0,
                      locked: locked,
                      onTap: () => widget.onSelect(index),
                      onRemove: index > 0 && !locked
                          ? () => widget.onRemove(index)
                          : null,
                    );
                  },
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.searchBarBorder.withValues(alpha: 0.85),
              ),
                ExposureZoneAddRow(
                  remainingCredits: widget.remainingAddSlots,
                  rowHeight: _ExposureZoneRowList.rowHeight,
                  listRadius: _ExposureZoneRowList.listRadius,
                  onTap: widget.onAdd,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExposureZoneRow extends StatelessWidget {
  const _ExposureZoneRow({
    required this.index,
    required this.point,
    required this.selected,
    required this.isFirst,
    required this.onTap,
    this.locked = false,
    this.onRemove,
  });

  final int index;
  final PushNotificationBasePoint point;
  final bool selected;
  final bool isFirst;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = PushCreditVisualTheme.forRecruitPoint(index);
    final isWorkplace = index == 0;
    final subtitle = locked
        ? '노출 중 · ${point.exposureExpiresAt == null ? 'D+1 23:59:59까지' : ShuttleExposurePolicy.remainingLabel(point.exposureExpiresAt!)}'
        : ExposurePointLabels.zoneRowSubtitle(index);
    final rowRadius = isFirst
        ? const BorderRadius.vertical(
            top: Radius.circular(_ExposureZoneRowList.listRadius),
          )
        : BorderRadius.zero;

    return Material(
      color: locked
          ? AppColors.textSecondary.withValues(alpha: 0.08)
          : selected
              ? theme.accentLight.withValues(alpha: 0.32)
              : AppColors.surface,
      borderRadius: rowRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: rowRadius,
        child: SizedBox(
          height: _ExposureZoneRowList.rowHeight,
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: selected ? theme.accent : Colors.transparent,
                  borderRadius: isFirst && selected
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(
                            _ExposureZoneRowList.listRadius,
                          ),
                        )
                      : BorderRadius.zero,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isWorkplace
                    ? Icons.storefront_outlined
                    : Icons.location_on_outlined,
                size: 18,
                color: locked
                    ? AppColors.textSecondary.withValues(alpha: 0.55)
                    : theme.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ExposurePointLabels.title(index),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: locked
                            ? AppColors.textSecondary.withValues(alpha: 0.7)
                            : selected
                                ? theme.accent
                                : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: locked
                              ? AppColors.textSecondary.withValues(alpha: 0.8)
                              : AppColors.textSecondary.withValues(alpha: 0.92),
                        ),
                      ),
                  ],
                ),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.lock_clock_outlined,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.55),
                  ),
                )
              else if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: theme.accent,
                  ),
                ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.75),
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
