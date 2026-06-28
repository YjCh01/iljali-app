import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/job_pin_activation_service.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/core/widgets/map_form_split_layout.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/corporate/presentation/widgets/select_all_toggle_bar.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

class JobPinActivationArgs {
  const JobPinActivationArgs({
    this.initialSettings,
    this.paymentPreference = CorporatePaymentPreference.auto,
  });

  final JobPostNotificationSettings? initialSettings;
  final CorporatePaymentPreference paymentPreference;
}

/// 일자리 알림핀 결제 — 핀 선택 · 노출 활성화
class JobPinActivationPage extends StatefulWidget {
  const JobPinActivationPage({super.key, this.args});

  final JobPinActivationArgs? args;

  @override
  State<JobPinActivationPage> createState() => _JobPinActivationPageState();
}

class _JobPinActivationPageState extends State<JobPinActivationPage> {
  late List<PushNotificationBasePoint> _points;
  bool _loading = true;
  bool _activating = false;
  final _selectedPinIds = <String>{};

  List<PushNotificationBasePoint> get _recruitmentPins => [
        for (var i = 1; i < _points.length; i++) _points[i],
      ];

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.args?.initialSettings?.basePoints ?? []);
    _applyDefaultSelection();
    _loading = false;
  }

  int get _unactivatedCount {
    var count = 0;
    for (var i = 1; i < _points.length; i++) {
      if (!_points[i].isExposureLocked) count++;
    }
    return count;
  }

  int get _chargeableCount => _recruitmentPins
      .where(
        (pin) =>
            _selectedPinIds.contains(pin.id) && !pin.isExposureLocked,
      )
      .length;

  bool get _canCheckout => _chargeableCount > 0 && !_activating;

  String get _checkoutButtonLabel {
    if (_activating) return '결제하기';
    if (_chargeableCount > 0) return '결제하기';
    if (_unactivatedCount == 0) return '모든 핀 노출 중';
    if (_selectedPinIds.isNotEmpty) return '노출 중인 핀은 결제할 수 없습니다';
    return '노출할 핀을 선택해 주세요';
  }

  void _applyDefaultSelection() {
    _selectedPinIds.clear();
    for (var i = 1; i < _points.length; i++) {
      if (!_points[i].isExposureLocked) {
        _selectedPinIds.add(_points[i].id);
      }
    }
  }

  void _togglePin(PushNotificationBasePoint pin) {
    if (pin.isExposureLocked) return;
    setState(() {
      if (_selectedPinIds.contains(pin.id)) {
        _selectedPinIds.remove(pin.id);
      } else {
        _selectedPinIds.add(pin.id);
      }
    });
  }

  List<PushNotificationBasePoint> get _selectablePins =>
      _recruitmentPins.where((pin) => !pin.isExposureLocked).toList();

  void _toggleSelectAllPins() {
    final selectable = _selectablePins;
    if (selectable.isEmpty) return;
    final ids = selectable.map((pin) => pin.id).toSet();
    final allSelected = ids.every(_selectedPinIds.contains);
    setState(() {
      if (allSelected) {
        _selectedPinIds.removeAll(ids);
      } else {
        _selectedPinIds.addAll(ids);
      }
    });
  }


  int get _checkoutTotalKrw =>
      _chargeableCount * PushPackageCatalog.exposureUnitPriceKrw;

  List<PushRadiusMapOverlayPoint> _mapOverlays() {
    return [
      for (var i = 0; i < _points.length; i++)
        PushRadiusMapOverlayPoint(
          coordinate: _points[i].coordinate,
          radiusMeters: _points[i].radiusTier.radiusMeters,
          label: ExposurePointLabels.title(i),
          pointIndex: i,
          draft: i > 0 &&
              !_points[i].isExposureLocked &&
              !_selectedPinIds.contains(_points[i].id),
          visualTheme: PushCreditVisualTheme.forRecruitPoint(i),
        ),
    ];
  }

  GeoCoordinate _mapCenter() {
    if (_points.isEmpty) return defaultPushMapCenter();
    return _points.first.coordinate;
  }

  Future<void> _checkout() async {
    if (_chargeableCount == 0 || _activating) return;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    setState(() => _activating = true);
    try {
      final service = JobPinActivationService();
      final result = await service.activateSelected(
        context: context,
        profile: profile,
        points: _points,
        selectedPinIds: _selectedPinIds,
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

      final updatedPoints = result.updatedPoints ?? _points;
      _points = updatedPoints;
      _applyDefaultSelection();

      if (result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(_buildResultSettings());
      return;
    } finally {
      if (mounted) {
        setState(() => _activating = false);
      }
    }
  }

  JobPostNotificationSettings _buildResultSettings() {
    final initial = widget.args?.initialSettings;
    final allPaid = _allRecruitmentPinsActivated(_points);
    if (initial != null) {
      return initial.copyWith(
        basePoints: _points,
        maxBasePointsAllowed: initial.maxBasePointsAllowed < _points.length
            ? _points.length
            : initial.maxBasePointsAllowed,
        paymentCompleted: allPaid,
        spotPaymentCompleted: allPaid,
      );
    }
    return JobPostNotificationSettings(
      basePoints: _points,
      maxBasePointsAllowed: _points.length,
      paymentCompleted: allPaid,
      designatedPointTier: DesignatedPointTier.onePoint,
      spotPaymentCompleted: allPaid,
    );
  }

  bool _allRecruitmentPinsActivated(List<PushNotificationBasePoint> points) {
    for (var i = 1; i < points.length; i++) {
      if (!points[i].isExposureLocked) return false;
    }
    return points.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final recruitmentPins = _recruitmentPins;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              Navigator.of(context).pop(_buildResultSettings()),
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          '일자리 알림핀 결제',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : recruitmentPins.isEmpty
              ? Center(
                  child: Text(
                    '설정된 일자리 알림핀이 없습니다.\n먼저 일자리 알림핀을 추가해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : MapStackSplitLayout(
                  map: PushRadiusMapPicker(
                            key: ValueKey(
                              'job_pin_pay_${_points.map((p) => p.id).join('-')}_'
                              '${_selectedPinIds.join('-')}',
                            ),
                            center: _mapCenter(),
                            radiusMeters: PushPackageCatalog.packagePushRadiusM,
                            hideZeroRadiusLabel: true,
                            centerEditable: false,
                            existingPoints: _mapOverlays(),
                            onCenterChanged: (_) {},
                            maxZoom: 21,
                            viewportSessionKey:
                                MapViewportSessionKeys.jobPinActivation,
                          ),
                  bottom: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '일자리 알림핀',
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
                        allSelected: _selectablePins.isNotEmpty &&
                            _selectablePins.every(
                              (pin) => _selectedPinIds.contains(pin.id),
                            ),
                        selectableCount: _selectablePins.length,
                        selectedCount: _selectedPinIds.length,
                        onToggle: _toggleSelectAllPins,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: recruitmentPins.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final pin = recruitmentPins[index];
                          final pinIndex = _points.indexOf(pin);
                          final theme =
                              PushCreditVisualTheme.forRecruitPoint(pinIndex);
                          final activated = pin.isExposureLocked;
                          final selected =
                              !activated && _selectedPinIds.contains(pin.id);
                          final highlighted = selected;
                          final remaining = pin.exposureExpiresAt == null
                              ? null
                              : ShuttleExposurePolicy.remainingLabel(
                                  pin.exposureExpiresAt!,
                                );

                          return Material(
                            color: activated
                                ? AppColors.textSecondary.withValues(alpha: 0.08)
                                : highlighted
                                    ? theme.accentLight.withValues(alpha: 0.32)
                                    : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: activated ? null : () => _togglePin(pin),
                              child: Container(
                                height: activated ? 52 : 46,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: activated
                                        ? AppColors.searchBarBorder
                                        : highlighted
                                            ? theme.accent.withValues(alpha: 0.55)
                                            : AppColors.searchBarBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color: activated
                                          ? AppColors.textSecondary
                                              .withValues(alpha: 0.55)
                                          : theme.accent,
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
                                            ExposurePointLabels.title(pinIndex),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: activated
                                                  ? AppColors.textSecondary
                                                      .withValues(alpha: 0.7)
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            activated
                                                ? '노출 중 · ${remaining ?? 'D+1 23:59:59까지'}'
                                                : selected
                                                    ? '선택됨'
                                                    : pin.addressLabel.isNotEmpty
                                                        ? pin.addressLabel
                                                        : '탭하여 선택',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: activated
                                                  ? AppColors.textSecondary
                                                      .withValues(alpha: 0.8)
                                                  : selected
                                                      ? theme.accent
                                                      : AppColors.textSecondary
                                                          .withValues(
                                                              alpha: 0.85),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (activated)
                                      Icon(
                                        Icons.lock_clock_outlined,
                                        size: 22,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.55),
                                      )
                                    else
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                        onPressed: () => _togglePin(pin),
                                        icon: Icon(
                                          selected
                                              ? Icons.check_circle
                                              : Icons.check_circle_outline,
                                          size: 22,
                                          color: selected
                                              ? theme.accent
                                              : AppColors.textSecondary
                                                  .withValues(alpha: 0.55),
                                        ),
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
                          if (_chargeableCount > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '결제 대상 $_chargeableCount곳 · '
                                '총 ${PushPackageCatalog.formatKrw(_checkoutTotalKrw)}원',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (_chargeableCount > 0) const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _canCheckout ? _checkout : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.primary
                                  .withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _activating
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
                          if (!_canCheckout && !_activating) ...[
                            const SizedBox(height: 8),
                            Text(
                              _unactivatedCount == 0
                                  ? '추가 결제가 필요 없습니다.'
                                  : '결제할 핀을 탭해 선택해 주세요.',
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
