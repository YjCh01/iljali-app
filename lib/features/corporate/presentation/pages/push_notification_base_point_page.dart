import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/usecases/search_workplace_address_usecase.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/presentation/widgets/exposure_zone_add_row.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';

/// 푸시 알림 거점 설정 — 반경(플랜별 거리) + 지정 포인트
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
    final settings = widget.initialSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      _points = List.from(settings.basePoints);
      _pointTier = settings.designatedPointTier;
      _activePointIndex = 0;
      final active = _points.first;
      _center = active.coordinate;
      _addressLabel = active.addressLabel;
      _radiusTier = active.radiusTier;
    } else if (widget.workplaceHint?.coordinate != null) {
      _center = widget.workplaceHint!.coordinate!;
      _addressLabel = widget.workplaceHint!.roadAddress;
      _radiusTier = PushRadiusTier.standard1km;
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
      _radiusTier = PushRadiusTier.standard1km;
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
    while (_points.length > _maxPoints) {
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

  /// 지역 푸시권 구매 후 반경·거점 한도를 지갑 기준으로 일괄 반영
  void _applyWalletDefaults() {
    _pointTier = PushPlanEnforcement.maxPointTier;
    _radiusTier = PushPlanEnforcement.defaultFreeRadiusTier;
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

  int get _availableCredits =>
      AuthSession.instance.currentUser?.corporateProfile?.pushWallet
          ?.packageRecruitCredits ??
      0;

  int get _remainingAddSlots => PushWalletCreditPolicy.configureRemainingAddSlots(
        slotRemaining:
            (_maxPoints - _points.length).clamp(0, _maxPoints),
        availableCredits: _availableCredits,
        recruitZoneCount:
            PushWalletCreditPolicy.recruitmentZoneCountFromPoints(_points),
      );

  /// 기본 거점(사업장)은 이동 불가 — 지역 푸시권으로 추가 거점 슬롯이 있을 때만 검색·이동
  bool get _canEditActivePointLocation =>
      _maxPoints > 1 && _activePointIndex > 0;

  /// [_addPoint]와 동일 — setState 밖에서 호출 가능
  void _addPointInternal() {
    if (_points.length >= _maxPoints) return;
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
    _points[_activePointIndex] = _points[_activePointIndex].copyWith(
      coordinate: _center,
      addressLabel: _addressLabel,
      radiusTier: _radiusTier,
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
    if (!PushPlanEnforcement.isRadiusAllowed(tier)) {
      _showPlanUpsell(
        '${tier.label}은(는) ${PushPackageCatalog.defaultPlanLabel} 한도를 초과합니다. '
        '추가 공고 노출 범위는 지역 푸시권이 필요합니다.',
      );
      return;
    }
    setState(() {
      _radiusTier = tier;
      _syncActivePointToList();
    });
  }

  Future<void> _openPushPackageShop() async {
    final purchased = await Navigator.of(context).pushNamed<bool?>(
      AppRoutes.corporatePushPackageShop,
    );
    if (!mounted) return;
    _refreshPlanLimitsAsync(afterUpgrade: purchased == true);
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
    if (_remainingAddSlots <= 0) return;
    if (_points.length >= _maxPoints) return;
    _syncActivePointToList();
    unawaited(_addPointWithCredit());
  }

  Future<void> _addPointWithCredit() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    if (_availableCredits <= 0) {
      await _openPushPackageShop();
      return;
    }
    final result =
        await PushWalletService().tryConsumeRecruitmentCredit(profile);
    if (!mounted) return;
    if (!result.success) {
      await _openPushPackageShop();
      return;
    }
    await _ensureWalletLoaded();
    if (!mounted) return;
    if (_remainingAddSlots <= 0 || _points.length >= _maxPoints) return;
    _syncActivePointToList();
    setState(_addPointInternal);
  }

  void _removePoint(int index) {
    if (index <= 0 || index >= _points.length) return;
    unawaited(_removePointWithRefund(index));
  }

  Future<void> _removePointWithRefund(int index) async {
    if (index <= 0 || index >= _points.length) return;
    _syncActivePointToList();
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile != null) {
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
    if (_remainingAddSlots <= 0) return;
    if (_points.length >= _maxPoints) {
      _showPlanUpsell(
        _maxPoints <= 1
            ? '추가 공고 노출 범위는 지역 푸시권 구매 후 이용할 수 있습니다.'
            : '설정 가능한 공고 노출 범위 $_maxPoints곳을 모두 사용 중입니다.',
      );
      return;
    }
    _addPoint();
  }

  void _confirm() {
    _syncActivePointToList();
    _clampAllToPlan();
    final maxPoints = _maxPoints;
    Navigator.of(context).pop(
      JobPostNotificationSettings(
        basePoints: List.unmodifiable(_points.take(maxPoints).toList()),
        pushCountLimit: PushPlanEnforcement.dailyPushLimit,
        maxBasePointsAllowed: maxPoints,
        paymentCompleted: _points.length <= PushPackageCatalog.baseLocationSlots,
        designatedPointTier: _pointTier,
        spotPaymentCompleted:
            _points.length <= PushPackageCatalog.baseLocationSlots,
      ),
    );
  }

  Future<void> _showPlanUpsell(String message) async {
    final goShop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지역 푸시권 필요'),
        content: Text(
          '$message\n\n'
          '지역 푸시권으로 모집지역 추가 및 추가 모집 발송을 진행할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('확인'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지역 푸시권 보기'),
          ),
        ],
      ),
    );
    if (goShop != true || !mounted) return;
    await _openPushPackageShop();
  }

  PushCreditVisualTheme get _visualTheme {
    final wallet =
        AuthSession.instance.currentUser?.corporateProfile?.pushWallet;
    return PushCreditVisualTheme.fromWallet(wallet);
  }

  @override
  Widget build(BuildContext context) {
    final walletTheme = _visualTheme;
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
        title: const Text('공고 노출 범위 설정'),
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
                  Text(
                    _points.length > 1
                        ? '${ExposurePointLabels.zoneRowSubtitle(_activePointIndex)} · '
                            '지역 푸시권 $_availableCredits회'
                        : ExposurePointLabels.zoneRowSubtitle(_activePointIndex),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  PushRadiusKmSlider(
                    selectedKm: _radiusTier.radiusKm,
                    allowedKmSteps: PushPlanEnforcement.allowedSliderKmSteps,
                    accentColor: activeTheme.accent,
                    suppressCenterLabel: true,
                    onChanged: (km) =>
                        _selectRadius(PushRadiusOptions.fromKm(km)),
                  ),
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
                  if (walletTheme.showBasicPassNotice) ...[
                    const SizedBox(height: 12),
                    BasicPassNoticeBanner(
                      backgroundColor:
                          walletTheme.accentLight.withValues(alpha: 0.22),
                      borderColor: walletTheme.accent.withValues(alpha: 0.35),
                      iconColor: walletTheme.accent,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _PushPackagePlanBanner(
                    pointCount: _points.length,
                    packageCredits: _availableCredits,
                    radiusUiLabel: ExposurePointLabels.zoneRowSubtitle(
                      _activePointIndex > 0 ? _activePointIndex : 0,
                    ),
                    onOpenShop: _openPushPackageShop,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: walletTheme.actionBackground,
                      foregroundColor: walletTheme.actionForeground,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  String get _confirmLabel {
    final credits = _availableCredits;
    if (_points.length <= 1) {
      return '근무지만 · 지역 푸시권 $credits회 · 설정 완료';
    }
    return '노출 ${_points.length}곳 · 지역 푸시권 $credits회 · 설정 완료';
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
            visualTheme: PushCreditVisualTheme.forRecruitPoint(i),
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
    final canAdd = widget.remainingAddSlots > 0;
    final scrollHeight = (widget.points.length.clamp(1, _ExposureZoneRowList.maxVisibleRows) *
            _ExposureZoneRowList.rowHeight)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '모집 지역',
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
                    return _ExposureZoneRow(
                      index: index,
                      point: widget.points[index],
                      selected: index == widget.activeIndex,
                      isFirst: index == 0,
                      onTap: () => widget.onSelect(index),
                      onRemove:
                          index > 0 ? () => widget.onRemove(index) : null,
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
                  onTap: canAdd ? widget.onAdd : null,
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
    this.onRemove,
  });

  final int index;
  final PushNotificationBasePoint point;
  final bool selected;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = PushCreditVisualTheme.forRecruitPoint(index);
    final isWorkplace = index == 0;
    final subtitle = ExposurePointLabels.zoneRowSubtitle(index);
    final rowRadius = isFirst
        ? const BorderRadius.vertical(
            top: Radius.circular(_ExposureZoneRowList.listRadius),
          )
        : BorderRadius.zero;

    return Material(
      color: selected
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
                color: theme.accent,
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
                        color: selected ? theme.accent : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
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

/// 기본 플랜 요약 + 지역 푸시권 상점 이동
class _PushPackagePlanBanner extends StatelessWidget {
  const _PushPackagePlanBanner({
    required this.pointCount,
    required this.packageCredits,
    required this.radiusUiLabel,
    required this.onOpenShop,
  });

  final int pointCount;
  final int packageCredits;
  final String radiusUiLabel;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    final plan = PartnershipPlanDefaults.activePlan;
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpenShop,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '모집지역을 추가해 더 넓게 모집해 보세요',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '노출 $pointCount곳 · 지역 푸시권 $packageCredits회 · '
                      '$radiusUiLabel · '
                      '근무지 푸시 일 ${plan.dailyPushLimitLabel} · '
                      '모집지역 추가 시 푸시권 1회 · '
                      '지역 푸시권 ${PartnershipPlanFormat.krw(plan.extraPushPriceKrw)}/회',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
