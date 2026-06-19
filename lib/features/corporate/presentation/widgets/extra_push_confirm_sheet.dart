import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/presentation/widgets/exposure_zone_add_row.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

const _kZoneListMaxHeight = 200.0;
const _kMapHeightExpanded = 220.0;
const _kMapHeightCollapsed = 340.0;

enum ExtraPushSheetMode {
  /// 공고관리 — 지역만 저장 (발송 없음)
  configureZones,
  /// @deprecated 발송 확인용 — 공고관리에서는 [configureZones] + 즉시 발송 분리
  dispatch,
}

/// 지원자 모집하기 — 위치·반경 확인 후 발송 / 모집지역 설정
class ExtraPushConfirmResult {
  const ExtraPushConfirmResult({
    required this.coordinate,
    required this.radiusTier,
    required this.activePointIndex,
    this.updatedBasePoints,
  });

  final GeoCoordinate coordinate;
  final PushRadiusTier radiusTier;
  final int activePointIndex;
  final List<PushNotificationBasePoint>? updatedBasePoints;
}

Future<ExtraPushConfirmResult?> showExtraPushConfirmSheet(
  BuildContext context, {
  required CorporateJobPost post,
  required int availablePushCredits,
  ExtraPushSheetMode mode = ExtraPushSheetMode.dispatch,
}) async {
  clearSnackBarQueue(context);
  final result = await showModalBottomSheet<ExtraPushConfirmResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ExtraPushConfirmSheet(
      post: post,
      availablePushCredits: availablePushCredits,
      mode: mode,
    ),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
  return result;
}

class _ExtraPushConfirmSheet extends StatefulWidget {
  const _ExtraPushConfirmSheet({
    required this.post,
    required this.availablePushCredits,
    required this.mode,
  });

  final CorporateJobPost post;
  final int availablePushCredits;
  final ExtraPushSheetMode mode;

  @override
  State<_ExtraPushConfirmSheet> createState() => _ExtraPushConfirmSheetState();
}

class _ExtraPushConfirmSheetState extends State<_ExtraPushConfirmSheet> {
  late List<PushNotificationBasePoint> _points;
  late List<PushNotificationBasePoint> _initialPoints;
  late int _activeIndex;
  late GeoCoordinate _center;
  late PushRadiusTier _radiusTier;
  late int _availableCredits;

  EmployerPushWallet? _wallet;
  bool _submitting = false;
  bool _showPurchasedHint = false;
  bool _zoneListExpanded = false;
  bool _mapPointerActive = false;
  ExposureActivationCreditMode? _lastZoneActivationMode;

  int get _recruitZoneCount =>
      PushWalletCreditPolicy.recruitmentZoneCountFromPoints(_points);

  int get _remainingSlots =>
      (_maxPoints - _points.length).clamp(0, _maxPoints);

  int get _configureRemainingAddSlots =>
      PushWalletCreditPolicy.configureRemainingAddSlots(
        slotRemaining: _remainingSlots,
        availableCredits: _availableCredits,
        recruitZoneCount: _recruitZoneCount,
      );

  @override
  void initState() {
    super.initState();
    final settings = widget.post.notificationSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      _points = List.from(settings.basePoints);
    } else {
      final workplace = JobPostWorkplaceResolver.resolve(widget.post);
      _points = [
        PushNotificationBasePoint(
          id: 'workplace',
          coordinate: workplace.coordinate ?? defaultPushMapCenter(),
          addressLabel: workplace.roadAddress,
          radiusTier: PushRadiusTier.standardFree1km,
          isPrimary: true,
        ),
      ];
    }
    _initialPoints = List.from(_points);
    _activeIndex = 0;
    _availableCredits = widget.availablePushCredits;
    _syncActiveFromPoint(_activeIndex);
    _refreshWallet();
  }

  bool get _isConfigureMode =>
      widget.mode == ExtraPushSheetMode.configureZones;

  int get _maxPoints {
    final wallet = _wallet ?? const EmployerPushWallet();
    if (_isConfigureMode) {
      return PushWalletCreditPolicy.configureModeMaxPoints(
        pointsLength: _points.length,
        availableCredits: _availableCredits,
        wallet: wallet,
      );
    }
    return PushWalletCreditPolicy.effectiveMaxExposurePoints(
      wallet: wallet,
      currentPointsLength: _points.length,
    );
  }

  PushCreditVisualTheme get _visualTheme =>
      PushCreditVisualTheme.forRecruitPoint(_activeIndex);

  bool get _pointsChanged =>
      _points.length != _initialPoints.length ||
      _points.asMap().entries.any((entry) {
        final i = entry.key;
        final p = entry.value;
        if (i >= _initialPoints.length) return true;
        final orig = _initialPoints[i];
        return orig.coordinate.latitude != p.coordinate.latitude ||
            orig.coordinate.longitude != p.coordinate.longitude ||
            orig.id != p.id;
      });

  void _syncActiveFromPoint(int index) {
    final point = _points[index];
    _center = point.coordinate;
    _radiusTier = point.radiusTier;
  }

  void _selectPoint(int index) {
    if (index == _activeIndex) return;
    _syncPointAtActiveIndex();
    setState(() {
      _activeIndex = index;
      _syncActiveFromPoint(index);
    });
  }

  void _syncPointAtActiveIndex() {
    _points[_activeIndex] = _points[_activeIndex].copyWith(
      coordinate: _center,
      radiusTier: _radiusTier,
    );
  }

  PushNotificationBasePoint _createRecruitmentPoint() {
    final base = _points.first.coordinate;
    final n = _points.length;
    final angle = (n - 1) * 0.9;
    final dist = 0.0035 + n * 0.0012;
    return PushNotificationBasePoint(
      id: 'recruit_${DateTime.now().millisecondsSinceEpoch}',
      coordinate: GeoCoordinate(
        latitude: base.latitude + dist * math.cos(angle),
        longitude: base.longitude + dist * math.sin(angle),
      ),
      addressLabel: '일자리 알림핀 $n',
      radiusTier: PushRadiusTier.standard1km,
      isPrimary: false,
      isPremiumSlot: true,
    );
  }

  void _appendRecruitmentPointAfterPurchase() {
    _appendRecruitmentPointAfterPurchaseInner(afterCreditConsumed: true);
  }

  void _appendRecruitmentPointAfterPurchaseInner({
    bool afterCreditConsumed = false,
  }) {
    if (!afterCreditConsumed && _points.length >= _maxPoints) return;
    setState(() {
      var point = _createRecruitmentPoint();
      if (afterCreditConsumed) {
        point = ExposureSlotPolicy.lockActivation(point);
      }
      _points.add(point);
      _activeIndex = _points.length - 1;
      _syncActiveFromPoint(_activeIndex);
      _showPurchasedHint = true;
    });
  }

  Future<bool> _consumeCreditForNewZone() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return false;

    final wallet = _wallet ?? await PushWalletService().loadWallet(profile);
    final mode = await ExposureActivationService().pickCreditMode(
      context,
      wallet: wallet,
      title: '일자리 알림핀 추가',
      subtitle: '일자리 알림핀 설치에 사용할 이용권을 선택하세요.',
    );
    if (mode == null) return false;

    final result = await ExposureActivationService().consumeCredit(
      profile: profile,
      mode: mode,
    );
    if (!result.success) return false;
    _lastZoneActivationMode = mode;
    await _refreshWallet();
    return true;
  }

  Future<void> _maybeSendIncludedPushForActivePoint() async {
    if (_lastZoneActivationMode != ExposureActivationCreditMode.exposureWithPush) {
      return;
    }
    _lastZoneActivationMode = null;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null || !mounted) return;

    final point = _points[_activeIndex];
    final target = ExposureActivationService().targetFromPinPoint(
      point: point,
      index: _activeIndex,
    );
    await ExposureActivationService().sendIncludedPush(
      context: context,
      profile: profile,
      post: widget.post,
      target: target,
    );
  }

  Future<void> _addRecruitmentZone() async {
    if (_submitting) return;
    _syncPointAtActiveIndex();
    if (_configureRemainingAddSlots <= 0 || _availableCredits <= 0) {
      await _openPackageShop();
      return;
    }
    if (_points.length >= _maxPoints) {
      await _openPackageShop();
      return;
    }
    setState(() => _submitting = true);
    final consumed = await _consumeCreditForNewZone();
    if (!mounted) return;
    if (!consumed) {
      setState(() => _submitting = false);
      await _openPackageShop();
      return;
    }
    setState(() {
      _submitting = false;
      final point = ExposureSlotPolicy.lockActivation(_createRecruitmentPoint());
      _points.add(point);
      _activeIndex = _points.length - 1;
      _syncActiveFromPoint(_activeIndex);
    });
    await _maybeSendIncludedPushForActivePoint();
  }

  Future<void> _removeRecruitmentZone(int index) async {
    if (_submitting || index <= 0 || index >= _points.length) return;
    _syncPointAtActiveIndex();
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    setState(() => _submitting = true);
    if (profile != null) {
      await PushWalletService().refundRecruitmentCredit(profile);
      await _refreshWallet();
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _points.removeAt(index);
      if (_activeIndex >= _points.length) {
        _activeIndex = _points.length - 1;
      } else if (_activeIndex > index) {
        _activeIndex -= 1;
      }
      _syncActiveFromPoint(_activeIndex);
    });
  }

  String get _configureMapHint {
    if (_activeIndex == 0) {
      return '근무지는 고정입니다. 일자리 알림핀을 선택해 위치를 지정하세요.';
    }
    return '${ExposurePointLabels.title(_activeIndex)} — 지도를 움직여 위치를 지정하세요.';
  }

  Future<void> _refreshWallet() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _availableCredits =
          wallet.packageCredits + wallet.exposurePushBundleCredits;
    });
  }

  Future<void> _openPackageShop() async {
    if (_submitting) return;
    final creditsBefore = _wallet?.packageRecruitCredits ?? 0;
    final purchased = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushPackageShop,
    );
    if (!mounted) return;
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _availableCredits =
          wallet.packageCredits + wallet.exposurePushBundleCredits;
      if (purchased == true &&
          wallet.packageRecruitCredits <= creditsBefore &&
          wallet.packageRecruitCredits > 0) {
        _showPurchasedHint = true;
      }
    });
    if (purchased == true && wallet.packageRecruitCredits > creditsBefore) {
      await _addRecruitmentZoneAfterPurchase();
    }
  }

  Future<void> _addRecruitmentZoneAfterPurchase() async {
    if (_points.length >= _maxPoints) return;
    final consumed = await _consumeCreditForNewZone();
    if (!mounted || !consumed) return;
    _appendRecruitmentPointAfterPurchase();
    await _maybeSendIncludedPushForActivePoint();
  }

  List<PushRadiusMapOverlayPoint> get _mapOverlays => [
        for (var i = 0; i < _points.length; i++)
          if (i != _activeIndex)
            PushRadiusMapOverlayPoint(
              coordinate: _points[i].coordinate,
              radiusMeters: _points[i].radiusMeters,
              label: ExposurePointLabels.title(i),
              pointIndex: i,
              visualTheme: PushCreditVisualTheme.forRecruitPoint(i),
            ),
      ];

  void _confirm() {
    if (_submitting) return;
    _syncPointAtActiveIndex();
    setState(() => _submitting = true);
    final points = (_isConfigureMode || _pointsChanged)
        ? ExposureSlotPolicy.syncPaidRecruitmentActivations(_points)
        : null;
    Navigator.of(context).pop(
      ExtraPushConfirmResult(
        coordinate: _center,
        radiusTier: _radiusTier,
        activePointIndex: _activeIndex,
        updatedBasePoints: points == null ? null : List.unmodifiable(points),
      ),
    );
  }

  int get _creditsRequired => PushWalletCreditPolicy.extraPushBillableCredits(
        before: _initialPoints,
        after: _points,
        activePointIndex: _activeIndex,
      );

  bool get _canConfirmDispatch {
    final paid =
        _wallet?.paidRecruitCreditsAvailable ?? _availableCredits;
    if (_creditsRequired > 0) {
      return paid >= _creditsRequired;
    }
    return paid > 0;
  }

  bool get _canConfirm {
    if (_isConfigureMode) {
      if (_points.isEmpty) return false;
      if (_creditsRequired > 0) {
        final paid =
            _wallet?.paidRecruitCreditsAvailable ?? _availableCredits;
        return paid >= _creditsRequired;
      }
      return true;
    }
    return _canConfirmDispatch;
  }

  @override
  Widget build(BuildContext context) {
    final theme = _visualTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final activeLabel = ExposurePointLabels.compactLine(
      _activeIndex,
      _points[_activeIndex],
    );
    final canConfirm = _canConfirm;
    final creditsRequired = _creditsRequired;
    final headerCredits = _isConfigureMode
        ? _availableCredits
        : (_wallet?.packageRecruitCredits ?? _availableCredits);
    final hasCredits = _isConfigureMode
        ? headerCredits > 0
        : headerCredits > 0;
    final showCreditWarning = !_isConfigureMode && !canConfirm;
    final mapHeight = _isConfigureMode
        ? _kMapHeightCollapsed
        : _points.length > 1 && _zoneListExpanded
            ? _kMapHeightExpanded
            : _kMapHeightCollapsed;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: _mapPointerActive
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: bottomInset + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.searchBarBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConfigureMode ? '일자리 알림핀 설정' : '지원자 모집하기',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: hasCredits
                              ? theme.accentLight.withValues(alpha: 0.35)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasCredits
                                ? theme.accent.withValues(alpha: 0.25)
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          hasCredits
                              ? '보유 $headerCredits회'
                              : '보유 0회',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasCredits
                                ? theme.accent
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                      if (_wallet != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _wallet!.recruitCreditsDetailLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (!_isConfigureMode) ...[
                const SizedBox(height: 12),
                Text(
                  _points.length > 1
                      ? '지도의 연한 영역을 탭하거나, 발송 지역 목록에서 선택하세요.'
                      : _activeIndex == 0
                          ? '근무지 주변에서 발송합니다.'
                          : '지도를 움직여 일자리 알림핀 위치를 지정한 뒤 발송해 주세요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
              if (showCreditWarning) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          creditsRequired > 0
                              ? '일자리 알림핀 $creditsRequired회 필요 · '
                                  '보유 ${_wallet?.paidRecruitCreditsAvailable ?? _availableCredits}회'
                              : '일자리 알림핀이 부족합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!_isConfigureMode && creditsRequired > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '이번 발송 시 일자리 알림핀 $creditsRequired회가 차감됩니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: theme.accent,
                  ),
                ),
              ],
              if (_showPurchasedHint) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: PushCreditVisualTheme.package.accentLight
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PushCreditVisualTheme.package.accent
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: PushCreditVisualTheme.package.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _points.length > 1
                              ? '일자리 알림핀이 충전되었습니다. 발송할 지역을 선택해 모집해 보세요.'
                              : '일자리 알림핀이 충전되었습니다. 보유 횟수가 늘었습니다.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary.withValues(alpha: 0.98),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isConfigureMode) ...[
                const SizedBox(height: 12),
                _ConfigureZoneSummary(
                  recruitZoneCount: _recruitZoneCount,
                  postingCredits: _availableCredits,
                  remainingAddSlots: _configureRemainingAddSlots,
                ),
                const SizedBox(height: 10),
                _RecruitmentZoneRowList(
                  points: _points,
                  activeIndex: _activeIndex,
                  maxSlots: _maxPoints,
                  remainingAddSlots: _configureRemainingAddSlots,
                  submitting: _submitting,
                  onSelect: _selectPoint,
                  onAdd: _addRecruitmentZone,
                  onRemove: _removeRecruitmentZone,
                ),
                const SizedBox(height: 8),
                Text(
                  _configureMapHint,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: _visualTheme.accent.withValues(alpha: 0.95),
                  ),
                ),
              ] else if (_points.length > 1) ...[
                const SizedBox(height: 12),
                _RecruitmentZoneList(
                  points: _points,
                  activeIndex: _activeIndex,
                  wallet: _wallet,
                  submitting: _submitting,
                  expanded: _zoneListExpanded,
                  onExpandedChanged: (expanded) {
                    setState(() => _zoneListExpanded = expanded);
                  },
                  onSelect: _selectPoint,
                ),
              ],
              const SizedBox(height: 14),
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  if (!_mapPointerActive) {
                    setState(() => _mapPointerActive = true);
                  }
                },
                onPointerUp: (_) {
                  if (_mapPointerActive) {
                    setState(() => _mapPointerActive = false);
                  }
                },
                onPointerCancel: (_) {
                  if (_mapPointerActive) {
                    setState(() => _mapPointerActive = false);
                  }
                },
                child: SizedBox(
                  height: mapHeight,
                  child: PushRadiusMapPicker(
                  key: ValueKey('recruit_map_$_activeIndex'),
                  center: _center,
                  radiusMeters: _radiusTier.radiusMeters,
                  centerEditable: _activeIndex > 0,
                  existingPoints: _mapOverlays,
                  activePointLabel: activeLabel,
                  visualTheme: theme,
                  onExistingPointTap: _selectPoint,
                  onCenterChanged: (coordinate) {
                    setState(() => _center = coordinate);
                  },
                  maxZoom: 21,
                  viewportSessionKey:
                      '${MapViewportSessionKeys.extraPushConfirm}_$_activeIndex',
                ),
              ),
              ),
              const SizedBox(height: 12),
              PushRadiusKmSlider(
                selectedKm: _radiusTier.radiusKm,
                allowedKmSteps: const [1],
                accentColor: theme.accent,
                onChanged: (_) {},
              ),
              const SizedBox(height: 4),
              Text(
                '$activeLabel · '
                '위치 ${_center.latitude.toStringAsFixed(4)}, '
                '${_center.longitude.toStringAsFixed(4)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.accent.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 14),
              _PackageShopLinkCard(onTap: _submitting ? null : _openPackageShop),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.searchBarBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed:
                          _submitting || !canConfirm ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.actionBackground,
                        foregroundColor: theme.actionForeground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.actionForeground,
                              ),
                            )
                          : Text(
                              _isConfigureMode ? '저장' : '지원자 모집하기',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigureZoneSummary extends StatelessWidget {
  const _ConfigureZoneSummary({
    required this.recruitZoneCount,
    required this.postingCredits,
    required this.remainingAddSlots,
  });

  static const _fluoro = Color(0xFFCCFF00);

  final int recruitZoneCount;
  final int postingCredits;
  final int remainingAddSlots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _fluoro.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF9AE600)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                size: 16,
                color: Color(0xFF1B5E20),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  postingCredits > 0
                      ? '일자리 알림핀 $postingCredits회'
                      : '일자리 알림핀 없음',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '근무지 1 · 일자리 알림핀 $recruitZoneCount · '
          '추가 가능 ${remainingAddSlots > 0 ? '$remainingAddSlots개' : '없음'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        if (recruitZoneCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '일자리 알림핀 추가 시 이용권 1회가 사용됩니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
      ],
    );
  }
}

/// 모집지역 설정 — 스크롤 목록 + 하단 고정 「+」
class _RecruitmentZoneRowList extends StatefulWidget {
  const _RecruitmentZoneRowList({
    required this.points,
    required this.activeIndex,
    required this.maxSlots,
    required this.remainingAddSlots,
    required this.submitting,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
  });

  static const rowHeight = 46.0;
  static const maxVisibleRows = 4;
  static const maxScrollHeight = rowHeight * maxVisibleRows;
  static const listRadius = 12.0;

  final List<PushNotificationBasePoint> points;
  final int activeIndex;
  final int maxSlots;
  final int remainingAddSlots;
  final bool submitting;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  State<_RecruitmentZoneRowList> createState() =>
      _RecruitmentZoneRowListState();
}

class _RecruitmentZoneRowListState extends State<_RecruitmentZoneRowList> {
  final _scrollController = ScrollController();
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.points.length;
  }

  @override
  void didUpdateWidget(covariant _RecruitmentZoneRowList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.length > _previousCount) {
      _previousCount = widget.points.length;
      _scrollToEnd();
    } else {
      _previousCount = widget.points.length;
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd =
        widget.remainingAddSlots > 0 && widget.points.length < widget.maxSlots;
    final scrollHeight = math.min(
      _RecruitmentZoneRowList.rowHeight * widget.points.length,
      _RecruitmentZoneRowList.maxScrollHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '설정 목록',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(_RecruitmentZoneRowList.listRadius),
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
                  itemCount: widget.points.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 1,
                    color:
                        AppColors.searchBarBorder.withValues(alpha: 0.85),
                  ),
                  itemBuilder: (context, index) {
                    return _ZoneRow(
                      index: index,
                      point: widget.points[index],
                      selected: index == widget.activeIndex,
                      isFirst: index == 0,
                      submitting: widget.submitting,
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
                rowHeight: _RecruitmentZoneRowList.rowHeight,
                listRadius: _RecruitmentZoneRowList.listRadius,
                onTap: canAdd && !widget.submitting ? widget.onAdd : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.index,
    required this.point,
    required this.selected,
    required this.isFirst,
    required this.submitting,
    required this.onTap,
    this.onRemove,
  });

  final int index;
  final PushNotificationBasePoint point;
  final bool selected;
  final bool isFirst;
  final bool submitting;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = PushCreditVisualTheme.forRecruitPoint(index);
    final isWorkplace = index == 0;
    final subtitle = ExposurePointLabels.zoneRowSubtitle(index);
    final rowRadius = isFirst
        ? const BorderRadius.vertical(
            top: Radius.circular(_RecruitmentZoneRowList.listRadius),
          )
        : BorderRadius.zero;

    return Material(
      color: selected
          ? theme.accentLight.withValues(alpha: 0.32)
          : AppColors.surface,
      borderRadius: rowRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: submitting ? null : onTap,
        borderRadius: rowRadius,
        child: SizedBox(
          height: _RecruitmentZoneRowList.rowHeight,
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: selected ? theme.accent : Colors.transparent,
                  borderRadius: isFirst && selected
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(
                            _RecruitmentZoneRowList.listRadius,
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
                    if (subtitle.isNotEmpty)
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
                  onPressed: submitting ? null : onRemove,
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

/// 발송 지역 — 접기/펼치기 (발송 모드 전용)
class _RecruitmentZoneList extends StatelessWidget {
  const _RecruitmentZoneList({
    required this.points,
    required this.activeIndex,
    required this.wallet,
    required this.submitting,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onSelect,
  });

  final List<PushNotificationBasePoint> points;
  final int activeIndex;
  final EmployerPushWallet? wallet;
  final bool submitting;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<int> onSelect;

  static const double _listMaxHeight = _kZoneListMaxHeight;

  @override
  Widget build(BuildContext context) {
    final maxSlots = wallet == null
        ? points.length
        : PushWalletCreditPolicy.effectiveMaxExposurePoints(
            wallet: wallet!,
            currentPointsLength: points.length,
          );
    final activeLabel = ExposurePointLabels.compactLine(
      activeIndex,
      points[activeIndex],
    );
    final listMaxHeight = points.length > 5
        ? _listMaxHeight
        : math.min(_listMaxHeight, 44.0 * points.length);

    final activeTheme = PushCreditVisualTheme.forRecruitPoint(activeIndex);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: submitting ? null : () => onExpandedChanged(!expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, expanded ? 6 : 10),
                child: Row(
                  children: [
                    const Text(
                      '발송 지역',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: activeTheme.accent,
                        ),
                      ),
                    ),
                    Text(
                      '${points.length}/$maxSlots곳',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listMaxHeight),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: points.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppColors.searchBarBorder.withValues(alpha: 0.7),
                ),
                itemBuilder: (context, index) {
                  final selected = index == activeIndex;
                  final tileTheme = PushCreditVisualTheme.forRecruitPoint(index);
                  return Material(
                    color: selected
                        ? tileTheme.accentLight.withValues(alpha: 0.28)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: submitting ? null : () => onSelect(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              index == 0
                                  ? Icons.storefront_outlined
                                  : Icons.location_on_outlined,
                              size: 20,
                              color: selected
                                  ? tileTheme.accent
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ExposurePointLabels.title(index),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? tileTheme.accent
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (ExposurePointLabels
                                      .zoneRowSubtitle(index)
                                      .isNotEmpty)
                                    Text(
                                      ExposurePointLabels.zoneRowSubtitle(index),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.9),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: tileTheme.accent,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PackageShopLinkCard extends StatelessWidget {
  const _PackageShopLinkCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 22,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '일자리 알림핀 구매',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '일자리 알림핀·PUSH 알림권을 늘리려면 이용권을 충전하세요.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
