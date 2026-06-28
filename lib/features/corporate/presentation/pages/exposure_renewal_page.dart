import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/employer_cash_balance_service.dart';
import 'package:map/features/corporate/domain/services/exposure_renewal_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_renewal_policy.dart';
import 'package:map/core/widgets/map_form_split_layout.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:map/features/corporate/presentation/widgets/select_all_toggle_bar.dart';

class ExposureRenewalArgs {
  const ExposureRenewalArgs({
    required this.jobPostId,
    this.paymentPreference = CorporatePaymentPreference.auto,
  });

  final String jobPostId;
  final CorporatePaymentPreference paymentPreference;
}

/// 노출 연장 — 만료·임박 핀·정류장 체크박스 선택 · 결제
class ExposureRenewalPage extends StatefulWidget {
  const ExposureRenewalPage({super.key, this.args});

  final ExposureRenewalArgs? args;

  @override
  State<ExposureRenewalPage> createState() => _ExposureRenewalPageState();
}

class _ExposureRenewalPageState extends State<ExposureRenewalPage> {
  CorporateJobPost? _post;
  Map<String, CommuteRoute> _routesById = {};
  List<ExposureRenewalCandidate> _candidates = [];
  final _selectedIds = <String>{};
  bool _loading = true;
  bool _renewing = false;
  int _packageCredits = 0;
  int _cashBalanceKrw = 0;

  int get _selectedCount => _selectedIds.length;
  int get _totalKrw =>
      _selectedCount * PushPackageCatalog.exposureUnitPriceKrw;

  bool get _canCheckout => _selectedCount > 0 && !_renewing;

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
    if (post == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final routeRepo = await CommuteRouteRepository.create();
    final routes = await routeRepo.loadAllActive();
    final routesById = {for (final r in routes) r.id: r};
    final candidates = ExposureRenewalPolicy.collectForPost(
      post: post.resolveShuttleExposureMetadata(),
      routesById: routesById,
    );

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    var packageCredits = 0;
    var cashBalance = 0;
    if (profile != null) {
      final wallet = await PushWalletService().loadWallet(profile);
      packageCredits = wallet.packageCredits;
      cashBalance = wallet.cashBalanceKrw;
    }

    if (!mounted) return;
    setState(() {
      _post = post;
      _routesById = routesById;
      _candidates = candidates;
      _selectedIds
        ..clear()
        ..addAll(candidates.map((c) => c.id));
      _packageCredits = packageCredits;
      _cashBalanceKrw = cashBalance;
      _loading = false;
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    if (_candidates.isEmpty) return;
    final allSelected =
        _candidates.every((c) => _selectedIds.contains(c.id));
    setState(() {
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_candidates.map((c) => c.id));
      }
    });
  }

  GeoCoordinate _mapCenter() {
    final settings = _post?.notificationSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      return settings.basePoints.first.coordinate;
    }
    for (final route in _routesById.values) {
      if (route.stops.isNotEmpty) return route.stops.first.coordinate;
    }
    return const GeoCoordinate(latitude: 37.5665, longitude: 126.978);
  }

  Future<void> _checkout() async {
    if (!_canCheckout || _post == null) return;
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    setState(() => _renewing = true);
    try {
      final result = await ExposureRenewalService().renewSelected(
        context: context,
        profile: profile,
        post: _post!,
        routesById: _routesById,
        selectedCandidateIds: _selectedIds,
        paymentPreference:
            widget.args?.paymentPreference ?? CorporatePaymentPreference.auto,
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '연장되었습니다.')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      if (result.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobPins = _candidates
        .where((c) => c.kind == ExposureRenewalCandidateKind.jobPin)
        .toList();
    final shuttleStops = _candidates
        .where((c) => c.kind == ExposureRenewalCandidateKind.shuttleStop)
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          '노출 연장',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _candidates.isEmpty
              ? Center(
                  child: Text(
                    '연장할 노출 항목이 없습니다.',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : MapStackSplitLayout(
                  topBanner: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '「${_post?.title ?? ''}」 · '
                        '이용 중이었던 핀·정류장 중 연장할 항목을 선택하세요.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  map: PushRadiusMapPicker(
                            center: _mapCenter(),
                            radiusMeters: 0,
                            hideZeroRadiusLabel: true,
                            centerEditable: false,
                            onCenterChanged: (_) {},
                          ),
                  bottom: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectAllToggleBar(
                      allSelected: _candidates.isNotEmpty &&
                          _candidates
                              .every((c) => _selectedIds.contains(c.id)),
                      selectableCount: _candidates.length,
                      selectedCount: _selectedCount,
                      onToggle: _toggleSelectAll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        children: [
                          if (jobPins.isNotEmpty) ...[
                            _sectionTitle('일자리 알림핀', Icons.push_pin_outlined),
                            for (final c in jobPins) _candidateRow(c),
                          ],
                          if (shuttleStops.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _sectionTitle(
                              '정류장 표시핀',
                              Icons.directions_bus_filled_outlined,
                            ),
                            for (final c in shuttleStops) _candidateRow(c),
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
                            '일자리 알림핀 $_packageCredits회 · '
                            '보유금 ${EmployerPushWallet(cashBalanceKrw: _cashBalanceKrw).cashBalanceLabel}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCount > 0
                                ? '선택 $_selectedCount곳 · '
                                    '${PushPackageCatalog.krwSuffix(_totalKrw)} '
                                    '(보유금·이용권 우선 차감)'
                                : '연장할 항목을 선택해 주세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => EmployerCashBalanceService()
                                .openChargePage(context)
                                .then((_) => _load()),
                            child: const Text('보유금 충전'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _canCheckout ? _checkout : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _renewing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _selectedCount > 0
                                        ? '연장 결제하기 · '
                                            '${PushPackageCatalog.krwSuffix(_totalKrw)}'
                                        : '연장할 항목 선택',
                                    style: const TextStyle(
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

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidateRow(ExposureRenewalCandidate c) {
    final selected = _selectedIds.contains(c.id);
    final accent = c.kind == ExposureRenewalCandidateKind.jobPin
        ? PushCreditVisualTheme.forRecruitPoint(c.pointIndex ?? 1).accent
        : (c.routeId != null
            ? ShuttleRouteColorUtils.parseHex(
                _routesById[c.routeId]?.overlayColorHex ?? '#5E35B1',
              )
            : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggle(c.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : AppColors.searchBarBorder,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) => _toggle(c.id),
                  activeColor: accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        c.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      c.urgencyLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.urgency == ExposureRenewalUrgency.expired
                            ? Colors.red.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                    Text(
                      ExposureRenewalPolicy.remainingOrEndedLabel(c.expiresAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
