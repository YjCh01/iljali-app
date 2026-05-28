import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 지원자 모집하기 — 위치·반경 확인 후 발송
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
}) {
  return showModalBottomSheet<ExtraPushConfirmResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ExtraPushConfirmSheet(
      post: post,
      availablePushCredits: availablePushCredits,
    ),
  );
}

class _ExtraPushConfirmSheet extends StatefulWidget {
  const _ExtraPushConfirmSheet({
    required this.post,
    required this.availablePushCredits,
  });

  final CorporateJobPost post;
  final int availablePushCredits;

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

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.post.notificationSettings!.basePoints);
    _initialPoints = List.from(_points);
    _activeIndex = 0;
    _availableCredits = widget.availablePushCredits;
    _syncActiveFromPoint(_activeIndex);
    _refreshWallet();
  }

  int get _maxPoints =>
      _wallet?.totalLocationSlots ?? _points.length.clamp(1, 999);

  PushCreditVisualTheme get _visualTheme {
    if (_activeIndex > 0) return PushCreditVisualTheme.package;
    return PushCreditVisualTheme.fromNextPushConsume(_wallet);
  }

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
      addressLabel: '모집지역 $n',
      radiusTier: PushRadiusTier.standard1km,
      isPrimary: false,
      isPremiumSlot: true,
    );
  }

  void _fillPointsToWalletSlots({bool selectNewRecruitment = false}) {
    final before = _points.length;
    while (_points.length < _maxPoints) {
      _points.add(_createRecruitmentPoint());
    }
    if (selectNewRecruitment && _points.length > before) {
      _activeIndex = before.clamp(1, _points.length - 1);
      if (_points.length == 2) _activeIndex = 1;
      _syncActiveFromPoint(_activeIndex);
      _showPurchasedHint = true;
    }
  }

  Future<void> _refreshWallet() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _availableCredits = wallet.availablePushCredits;
      _fillPointsToWalletSlots();
    });
  }

  Future<void> _openPackageShop() async {
    if (_submitting) return;
    final slotsBefore = _wallet?.totalLocationSlots ?? _points.length;
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
      _availableCredits = wallet.availablePushCredits;
      final gainedSlot = wallet.totalLocationSlots > slotsBefore;
      _fillPointsToWalletSlots(
        selectNewRecruitment: purchased == true && gainedSlot,
      );
      if (purchased == true && !gainedSlot && _points.length > 1) {
        _activeIndex = 1;
        _syncActiveFromPoint(_activeIndex);
        _showPurchasedHint = true;
      } else if (purchased == true && wallet.packageCredits > 0) {
        _showPurchasedHint = true;
      }
    });
  }

  List<PushRadiusMapOverlayPoint> get _mapOverlays => [
        for (var i = 0; i < _points.length; i++)
          if (i != _activeIndex)
            PushRadiusMapOverlayPoint(
              coordinate: _points[i].coordinate,
              radiusMeters: _points[i].radiusMeters,
              label: ExposurePointLabels.title(i),
              pointIndex: i,
            ),
      ];

  void _confirm() {
    if (_submitting) return;
    _syncPointAtActiveIndex();
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      ExtraPushConfirmResult(
        coordinate: _center,
        radiusTier: _radiusTier,
        activePointIndex: _activeIndex,
        updatedBasePoints: _pointsChanged ? List.unmodifiable(_points) : null,
      ),
    );
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

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
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
                        const Text(
                          '지원자 모집하기',
                          style: TextStyle(
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.accentLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '보유 $_availableCredits회',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _activeIndex == 0
                    ? '근무지 주변에서 발송할지, 아래에서 모집지역을 선택하세요.'
                    : '지도를 움직여 모집지역 위치를 지정한 뒤 발송해 주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
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
                              ? '패키지가 충전되었습니다. 모집지역을 선택해 바로 발송해 보세요.'
                              : '패키지가 충전되었습니다. 보유 횟수가 늘었습니다.',
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
              if (theme.showBasicPassNotice && _activeIndex == 0) ...[
                const SizedBox(height: 10),
                BasicPassNoticeBanner(
                  backgroundColor: theme.accentLight.withValues(alpha: 0.22),
                  borderColor: theme.accent.withValues(alpha: 0.35),
                  iconColor: theme.accent,
                ),
              ],
              if (_points.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _points.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final selected = index == _activeIndex;
                      final chipTheme = index == 0
                          ? PushCreditVisualTheme.fromNextPushConsume(_wallet)
                          : PushCreditVisualTheme.package;
                      return ChoiceChip(
                        label: Text(
                          ExposurePointLabels.compactLine(
                            index,
                            _points[index],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? chipTheme.actionForeground
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: selected,
                        onSelected: _submitting
                            ? null
                            : (_) => _selectPoint(index),
                        selectedColor: chipTheme.actionBackground,
                        backgroundColor: AppColors.background,
                        side: BorderSide(
                          color: selected
                              ? chipTheme.accent.withValues(alpha: 0.45)
                              : AppColors.searchBarBorder,
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 240,
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
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
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
                      onPressed: _submitting ? null : _confirm,
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
                          : const Text(
                              '지원자 모집하기',
                              style: TextStyle(
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
                      '이용권 및 패키지 구매',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '노출 범위·모집 횟수를 늘리려면 패키지를 구매하세요.',
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
