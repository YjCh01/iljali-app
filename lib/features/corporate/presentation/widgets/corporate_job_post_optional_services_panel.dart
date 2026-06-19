import 'package:flutter/material.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/presentation/pages/shuttle_stop_payment_page.dart';
import 'package:map/features/commute/presentation/pages/shuttle_stop_activation_page.dart';
import 'package:map/features/corporate/presentation/pages/job_pin_activation_page.dart';
import 'package:map/features/corporate/presentation/pages/push_ticket_use_page.dart';
import 'package:map/features/corporate/presentation/widgets/push_ticket_purchase_sheet.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_delegate_info.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_line_item.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_access_service.dart';
import 'package:map/features/corporate/domain/services/job_post_payment_request_service.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_navigation_helper.dart';
import 'package:map/features/corporate/presentation/widgets/payment/job_post_payment_request_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_delegate_banner.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_service_action_style.dart';
import 'package:map/features/corporate/presentation/widgets/urgent_hire_brand.dart';

/// 공고 — 유료 서비스 (접이식)
class CorporateJobPostOptionalServicesPanel extends StatefulWidget {
  const CorporateJobPostOptionalServicesPanel({
    super.key,
    this.notificationSettings,
    required this.onConfigurePins,
    this.onNotificationSettingsChanged,
    this.shuttleRouteId,
    required this.onShuttleRouteChanged,
    this.workplaceReady = true,
    required this.jobTitle,
    this.jobPostId,
    this.hasShuttleRouteOverlay = false,
  });

  final JobPostNotificationSettings? notificationSettings;
  final VoidCallback onConfigurePins;
  final ValueChanged<JobPostNotificationSettings>? onNotificationSettingsChanged;
  final String? shuttleRouteId;
  final void Function({
    String? routeId,
    bool? hasShuttleRouteOverlay,
    List<String>? linkedRouteIds,
  }) onShuttleRouteChanged;
  final bool workplaceReady;
  final String jobTitle;
  final String? jobPostId;
  final bool hasShuttleRouteOverlay;

  @override
  State<CorporateJobPostOptionalServicesPanel> createState() =>
      _CorporateJobPostOptionalServicesPanelState();
}

class _CorporateJobPostOptionalServicesPanelState
    extends State<CorporateJobPostOptionalServicesPanel> {
  String? _shuttleRouteName;
  int _shuttleStopCount = 0;
  int _shuttleExposedStopCount = 0;
  int _shuttlePushEligibleExposedCount = 0;
  int _shuttleUnpaidStopCount = 0;
  DateTime? _shuttleExposureExpiresAt;
  bool _shuttleExposureActive = false;
  int _pushTicketCredits = 0;
  int _exposureCredits = 0;
  JobPostNotificationSettings? _fallbackNotificationSettings;
  String? _fallbackJobPostId;
  CorporatePaymentDelegateInfo? _delegateInfo;
  List<JobPostPaymentRequest> _myPendingRequests = [];

  JobPostNotificationSettings? get _effectiveNotificationSettings =>
      widget.notificationSettings ?? _fallbackNotificationSettings;

  String? get _effectiveShuttleRouteId =>
      widget.shuttleRouteId?.trim().isNotEmpty == true
          ? widget.shuttleRouteId
          : null;

  String? get _effectiveJobPostId => widget.jobPostId ?? _fallbackJobPostId;

  bool get _effectiveHasShuttleOverlay => widget.hasShuttleRouteOverlay;

  List<PushNotificationBasePoint> get _syncedRecruitmentPoints {
    final points = _effectiveNotificationSettings?.basePoints ?? const [];
    return ExposureSlotPolicy.syncPaidRecruitmentActivations(points);
  }

  bool get _hasExtraPins => _syncedRecruitmentPoints.length > 1;

  int get _recruitmentPinCount =>
      _hasExtraPins ? _syncedRecruitmentPoints.length - 1 : 0;

  bool get _hasActivatedJobPins {
    final points = _effectiveNotificationSettings?.basePoints ?? const [];
    for (var i = 1; i < points.length; i++) {
      if (points[i].isExposureLocked) return true;
    }
    return false;
  }

  int get _activatedJobPinCount {
    final points = _effectiveNotificationSettings?.basePoints ?? const [];
    var count = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].isExposureLocked) count++;
    }
    return count;
  }

  int get _pushEligibleLocationCount =>
      _activatedJobPinCount +
      (_shuttleExposureActive ? _shuttlePushEligibleExposedCount : 0);

  bool get _canUsePushTicket =>
      _pushTicketCredits > 0 && _pushEligibleLocationCount > 0;

  bool get _hasShuttleRoute => _shuttleStopCount > 0;

  bool get _needsShuttlePayment =>
      _hasShuttleRoute && _shuttleUnpaidStopCount > 0;

  @override
  void initState() {
    super.initState();
    _bootstrapContext();
    AuthSession.instance.corporateProfileRevision.addListener(_onProfileChanged);
  }

  Future<void> _bootstrapContext() async {
    await _loadPaymentAccess();
    await _loadFallbackJobContext();
    await _loadShuttleRouteName();
    await _loadPushWallet();
  }

  Future<void> _loadPaymentAccess() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final email = AuthSession.instance.currentUser?.email ?? '';
    if (profile == null || email.isEmpty) return;
    final access = CorporatePaymentAccessService();
    final delegate = await access.loadDelegateInfo(
      companyKey: profile.companyKey,
      email: email,
    );
    final pending = await JobPostPaymentRequestService().listMyPending(
      companyKey: profile.companyKey,
      requesterEmail: email,
    );
    if (!mounted) return;
    setState(() {
      _delegateInfo = delegate;
      _myPendingRequests = pending;
    });
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision
        .removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    _loadPushWallet();
    _loadShuttleRouteName();
  }

  @override
  void didUpdateWidget(covariant CorporateJobPostOptionalServicesPanel old) {
    super.didUpdateWidget(old);
    if (old.shuttleRouteId != widget.shuttleRouteId ||
        old.hasShuttleRouteOverlay != widget.hasShuttleRouteOverlay ||
        old.jobPostId != widget.jobPostId ||
        old.notificationSettings != widget.notificationSettings) {
      _loadShuttleRouteName();
    }
  }

  Future<void> _loadFallbackJobContext() async {
    if (widget.notificationSettings != null &&
        widget.shuttleRouteId?.trim().isNotEmpty == true) {
      return;
    }

    final posts = await const GetCorporateJobPostsUseCase(
      CorporateJobPostLocalDataSourceImpl(),
    ).call();
    if (!mounted || posts.isEmpty) return;

    CorporateJobPost? selected;
    for (final post in posts) {
      if (post.status != CorporateJobPostStatus.recruiting) continue;
      final points = post.notificationSettings?.basePoints ?? const [];
      final synced = ExposureSlotPolicy.syncPaidRecruitmentActivations(points);
      final hasActivatedPin =
          synced.skip(1).any((point) => point.exposureActivated);
      if (hasActivatedPin ||
          post.commuteRouteId?.trim().isNotEmpty == true ||
          post.notificationSettings != null) {
        selected = post;
        break;
      }
    }
    selected ??= posts.firstWhere(
      (post) => post.status == CorporateJobPostStatus.recruiting,
      orElse: () => posts.first,
    );

    if (!mounted) return;
    setState(() {
      if (widget.notificationSettings == null) {
        _fallbackNotificationSettings = selected!.notificationSettings;
      }
      if (widget.jobPostId == null) {
        _fallbackJobPostId = selected!.id;
      }
    });
  }

  Future<void> _loadPushWallet() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() {
      _pushTicketCredits = wallet.pushTicketCredits;
      _exposureCredits = wallet.packageCredits;
    });
  }

  void _applyEmptyShuttleRouteState() {
    _shuttleRouteName = null;
    _shuttleStopCount = 0;
    _shuttleExposedStopCount = 0;
    _shuttlePushEligibleExposedCount = 0;
    _shuttleUnpaidStopCount = 0;
    _shuttleExposureExpiresAt = null;
    _shuttleExposureActive = false;
  }

  Future<void> _loadShuttleRouteName() async {
    final jobPostId = _effectiveJobPostId?.trim();
    if (jobPostId == null || jobPostId.isEmpty) {
      if (mounted) setState(_applyEmptyShuttleRouteState);
      return;
    }

    final post = await const CorporateJobPostLocalDataSourceImpl()
        .findById(jobPostId);
    if (!mounted) return;
    if (post == null || post.registeredShuttleStopCount == 0) {
      setState(_applyEmptyShuttleRouteState);
      return;
    }

    var resolved = post.resolveShuttleExposureMetadata();
    final repo = await CommuteRouteRepository.create();
    final routeIds = <String>{
      ...resolved.effectiveLinkedCommuteRouteIds,
      for (final entry in resolved.shuttleRegisteredStopIdsByRoute.entries)
        if (entry.value.isNotEmpty) entry.key.trim(),
    }.where((id) => id.isNotEmpty);
    var reconciled = resolved;
    if (routeIds.isNotEmpty) {
      final routes = <CommuteRoute>[];
      for (final routeId in routeIds) {
        final route = await repo.findById(routeId);
        if (route != null) routes.add(route);
      }
      reconciled = resolved.reconcileShuttleExposureWithRoutes(routes);
      if (reconciled != post) {
        await const CorporateJobPostLocalDataSourceImpl()
            .updateJobPost(reconciled);
      }
    }

    final routeNames = <String>[];
    var totalRegistered = 0;
    var pushEligibleExposed = 0;
    final legacyAllPaid = reconciled.shuttlePaidStopIdsByRoute.isEmpty;

    for (final routeId in routeIds) {
      final route = await repo.findById(routeId);
      if (route == null) continue;
      final registeredIds =
          reconciled.shuttleRegisteredStopIdsByRoute[routeId] ?? const [];
      if (registeredIds.isEmpty) continue;

      routeNames.add(route.routeName);
      totalRegistered += ShuttleRouteStopPolicy.filterRegistrableStopIds(
        stopIds: registeredIds,
        routeStops: route.stops,
      ).length;

      if (!reconciled.isShuttleExposureActive) continue;

      final paidIds =
          (reconciled.shuttlePaidStopIdsByRoute[routeId] ?? const []).toSet();
      for (final stopId in registeredIds) {
        CommuteRouteStop? matched;
        for (final stop in route.stops) {
          if (stop.id == stopId) {
            matched = stop;
            break;
          }
        }
        if (matched != null &&
            ShuttleRouteStopPolicy.isWorkplaceStop(matched)) {
          continue;
        }
        if (legacyAllPaid || paidIds.contains(stopId)) {
          pushEligibleExposed++;
        }
      }
    }

    if (!mounted) return;
    if (totalRegistered == 0) {
      setState(_applyEmptyShuttleRouteState);
      return;
    }

    final routeLabel = routeNames.length == 1
        ? routeNames.first
        : routeNames.join(', ');
    final exposedCount = reconciled.isShuttleExposureActive
        ? totalRegistered - reconciled.unpaidRegisteredShuttleStopCount
        : 0;

    setState(() {
      _shuttleRouteName = routeLabel;
      _shuttleStopCount = totalRegistered;
      _shuttleExposedStopCount = exposedCount;
      _shuttlePushEligibleExposedCount = pushEligibleExposed;
      _shuttleUnpaidStopCount = reconciled.unpaidRegisteredShuttleStopCount;
      _shuttleExposureExpiresAt = reconciled.shuttleExposureExpiresAt;
      _shuttleExposureActive = reconciled.isShuttleExposureActive;
    });
  }

  String _shuttleExposurePhaseLabel() {
    final remaining = _shuttleExposureExpiresAt == null
        ? null
        : ShuttleExposurePolicy.remainingLabel(_shuttleExposureExpiresAt!);
    if (remaining == null) {
      return '노출 중 · $_shuttleExposedStopCount핀 활성화 · 추가만 가능';
    }
    return '노출 중 · $remaining · 추가만 가능';
  }

  int get _unactivatedJobPinCount {
    final points = _effectiveNotificationSettings?.basePoints ?? const [];
    var count = 0;
    for (var i = 1; i < points.length; i++) {
      if (!points[i].isExposureLocked) count++;
    }
    return count;
  }

  int get _unactivatedShuttleStopCount => _shuttleUnpaidStopCount;

  String _jobPinExposurePhaseLabel() {
    final points = _effectiveNotificationSettings?.basePoints ?? const [];
    DateTime? nearestExpiry;
    for (var i = 1; i < points.length; i++) {
      final expires = points[i].exposureExpiresAt;
      if (!points[i].isExposureLocked || expires == null) continue;
      if (nearestExpiry == null || expires.isBefore(nearestExpiry)) {
        nearestExpiry = expires;
      }
    }
    final remaining = nearestExpiry == null
        ? null
        : ShuttleExposurePolicy.remainingLabel(nearestExpiry);
    if (remaining == null) {
      return '노출 중 · $_activatedJobPinCount핀 활성화 · 추가만 가능';
    }
    return '노출 중 · $remaining · 추가만 가능';
  }

  bool get _hasPaymentRequestTarget => _buildPaymentLineItems().isNotEmpty;

  Widget _buildExposurePaymentActions({
    required String product,
    required bool enabled,
    required VoidCallback onDirectPay,
    required VoidCallback onRequestPay,
  }) {
    if (!_showDualPayment) {
      return _ServicePaymentButton(
        onPressed: enabled ? onDirectPay : null,
        icon: Icons.payments_outlined,
        label: '$product 결제',
      );
    }
    final delegate = _delegateInfo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ServicePaymentButton(
          onPressed: enabled ? onDirectPay : null,
          icon: Icons.payments_outlined,
          label: delegate.directPayLabel(product),
        ),
        const SizedBox(height: 8),
        _ServiceOutlineButton(
          onPressed: enabled ? onRequestPay : null,
          icon: Icons.send_outlined,
          label: delegate.exposureActionLabel(product),
        ),
      ],
    );
  }

  List<JobPostPaymentLineItem> _buildPaymentLineItems() {
    final items = <JobPostPaymentLineItem>[];
    if (_hasExtraPins && _unactivatedJobPinCount > 0) {
      final count = _unactivatedJobPinCount;
      items.add(
        JobPostPaymentLineItem(
          label: '일자리 알림핀 노출',
          detail: '미노출 $count곳',
          amountKrw: count * PushPackageCatalog.exposureUnitPriceKrw,
          bundle: PushPaymentBundle(
            radiusTier: PushRadiusTier.standard1km,
            pointTier: DesignatedPointTier.onePoint,
            spotCount: count,
            isExtraPush: true,
            extraPushFeeKrw: count * PushPackageCatalog.exposureUnitPriceKrw,
            paymentKind: JobPostPaymentRequestKind.jobPinExposure,
          ),
          kind: JobPostPaymentRequestKind.jobPinExposure,
        ),
      );
    }
    if (_needsShuttlePayment && _unactivatedShuttleStopCount > 0) {
      final count = _unactivatedShuttleStopCount;
      items.add(
        JobPostPaymentLineItem(
          label: '정류장 표시핀 노출',
          detail: '미노출 $count곳',
          amountKrw: count * PushPackageCatalog.exposureUnitPriceKrw,
          bundle: PushPaymentBundle(
            radiusTier: PushRadiusTier.standard1km,
            pointTier: DesignatedPointTier.onePoint,
            spotCount: count,
            isExtraPush: true,
            extraPushFeeKrw: count * PushPackageCatalog.exposureUnitPriceKrw,
            paymentKind: JobPostPaymentRequestKind.shuttleStopExposure,
          ),
          kind: JobPostPaymentRequestKind.shuttleStopExposure,
        ),
      );
    }
    if (_pushTicketCredits == 0) {
      items.add(
        JobPostPaymentLineItem(
          label: 'PUSH 이용권',
          detail: '1회',
          amountKrw: PushPackageCatalog.pushOnlyUnitPriceKrw,
          bundle: const PushPaymentBundle.pushTicket(),
          kind: JobPostPaymentRequestKind.pushTicket,
        ),
      );
    }
    return items;
  }

  Future<void> _openPaymentRequestSheet() async {
    final delegate = _delegateInfo;
    if (delegate == null || !delegate.canRequestPayment) return;
    final items = _buildPaymentLineItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 요청할 항목이 없습니다.')),
      );
      return;
    }
    final confirmed = await showJobPostPaymentRequestSheet(
      context: context,
      delegate: delegate,
      items: items,
    );
    if (confirmed != true || !mounted) return;
    await CorporatePaymentNavigationHelper().sendBatchRequests(
      context: context,
      items: items,
      jobTitle: widget.jobTitle,
      jobPostId: _effectiveJobPostId,
    );
    await _loadPaymentAccess();
    await _loadPushWallet();
  }

  Future<void> _cancelMyRequest(JobPostPaymentRequest request) async {
    final email = AuthSession.instance.currentUser?.email ?? '';
    final ok = await JobPostPaymentRequestService().cancel(
      id: request.id,
      requesterEmail: email,
    );
    if (!mounted) return;
    if (ok) await _loadPaymentAccess();
  }

  Future<void> _openShuttleStopFlow({
    CorporatePaymentPreference preference = CorporatePaymentPreference.auto,
  }) async {
    final result =
        await Navigator.of(context).pushNamed<ShuttleStopActivationPageResult>(
      AppRoutes.corporateShuttleStopActivation,
      arguments: ShuttleStopActivationArgs(
        preferredRouteId: widget.shuttleRouteId,
        jobPostId: _effectiveJobPostId,
        paymentPreference: preference,
      ),
    );
    if (!mounted) return;
    if (result != null && result.registered) {
      widget.onShuttleRouteChanged(
        routeId: result.routeIds.isNotEmpty ? result.routeIds.first : null,
        linkedRouteIds:
            result.routeIds.isNotEmpty ? result.routeIds : const [],
      );
    }
    await _loadShuttleRouteName();
    await _loadPushWallet();
  }

  Future<void> _openShuttlePinEditor() async {
    await _openShuttleStopFlow();
  }

  bool get _showDualPayment => _delegateInfo?.showDualPaymentActions == true;

  Future<void> _openShuttlePayment({
    CorporatePaymentPreference preference = CorporatePaymentPreference.direct,
  }) async {
    if (!_needsShuttlePayment) return;

    final jobPostId = _effectiveJobPostId?.trim();
    if (jobPostId == null || jobPostId.isEmpty) return;

    final result =
        await Navigator.of(context).pushNamed<ShuttleStopPaymentPageResult>(
      AppRoutes.corporateShuttleStopPayment,
      arguments: ShuttleStopPaymentArgs(
        jobPostId: jobPostId,
        paymentPreference: preference,
      ),
    );
    if (!mounted) return;

    if (result?.paid == true) {
      widget.onShuttleRouteChanged(hasShuttleRouteOverlay: true);
    }
    await _loadShuttleRouteName();
    await _loadPushWallet();
  }

  Future<void> _openJobPinPayment({
    CorporatePaymentPreference preference = CorporatePaymentPreference.direct,
  }) async {
    final result =
        await Navigator.of(context).pushNamed<JobPostNotificationSettings>(
      AppRoutes.corporateJobPinActivation,
      arguments: JobPinActivationArgs(
        initialSettings: _effectiveNotificationSettings,
        paymentPreference: preference,
      ),
    );
    if (result != null) {
      widget.onNotificationSettingsChanged?.call(result);
      if (widget.notificationSettings == null) {
        setState(() => _fallbackNotificationSettings = result);
      }
    }
    await _loadPushWallet();
  }

  Future<void> _requestPushTicketPayment() async {
    const bundle = PushPaymentBundle.pushTicket();
    await CorporatePaymentNavigationHelper().payOrRequest(
      context: context,
      bundle: bundle,
      kind: JobPostPaymentRequestKind.pushTicket,
      jobTitle: widget.jobTitle,
      jobPostId: _effectiveJobPostId,
      productLabel: 'PUSH 이용권',
      preference: CorporatePaymentPreference.request,
    );
    if (!mounted) return;
    await _loadPaymentAccess();
    await _loadPushWallet();
  }

  Future<void> _openPushTicketPurchase() async {
    if (_pushEligibleLocationCount == 0 &&
        (_hasExtraPins || _hasShuttleRoute)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PUSH 이용권 구매'),
          content: const Text(
            '아직 노출 활성화된 위치가 없습니다.\n\n'
            'PUSH 이용권은 노출된 일자리 알림핀·정류장에서만 발송할 수 있습니다. '
            '구매 후에도 각 항목의 「결제」로 노출을 먼저 활성화해야 사용할 수 있습니다.\n\n'
            '그래도 구매하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('구매 계속'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final purchased = await showPushTicketPurchaseSheet(
      context,
      pushCredits: _pushTicketCredits,
      eligibleLocations: _pushEligibleLocationCount,
    );
    if (purchased == true && mounted) {
      await _loadPushWallet();
    }
  }

  void _openPushTicketUse() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.corporatePushTicketUse,
      arguments: PushTicketUseArgs(
        jobTitle: widget.jobTitle,
        jobPostId: _effectiveJobPostId,
        notificationSettings: _effectiveNotificationSettings,
        shuttleRouteId: _effectiveShuttleRouteId,
        hasShuttleRouteOverlay: _effectiveHasShuttleOverlay,
      ),
    );
    await _loadPushWallet();
    await _loadShuttleRouteName();
    await _loadFallbackJobContext();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_delegateInfo != null &&
            _delegateInfo!.hasAcceptedDelegation &&
            _delegateInfo!.canRequestPayment)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PaymentDelegateBanner(
              delegate: _delegateInfo!,
              pendingRequests: _myPendingRequests,
              onCancelRequest: _cancelMyRequest,
            ),
          ),
        _PaidServiceCategoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildJobPinExpansion(),
              const Divider(height: 1),
              _buildShuttlePinExpansion(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PaidServiceCategoryCard(
          child: _buildPushTicketSection(),
        ),
        if (_showDualPayment) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _hasPaymentRequestTarget ? _openPaymentRequestSheet : null,
            icon: const Icon(Icons.send_outlined, size: 18),
            label: Text(_delegateInfo!.batchRequestButtonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJobPinExpansion() {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Row(
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: 20,
            color: _hasExtraPins
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '일자리 알림핀',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_hasExtraPins)
            _ExposureStepBadge(
              isExposed: _hasActivatedJobPins,
              accentColor: AppColors.primary,
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '일자리 알림핀을 지도 상의 번화가, 인구 밀집지역 등에 추가하여 '
                '모집 효과를 높일 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 10),
              _WalletCreditLabel(
                label: '노출 이용권',
                count: _exposureCredits,
                detailLine: _hasExtraPins
                    ? '등록 $_recruitmentPinCount핀 · 노출 $_activatedJobPinCount핀'
                    : null,
              ),
              const SizedBox(height: 8),
              if (_hasExtraPins)
                _ConfiguredServiceRow(
                  primaryLabel:
                      '일자리 알림핀 등록 완료\n$_recruitmentPinCount핀',
                  phaseLabel: _hasActivatedJobPins
                      ? _jobPinExposurePhaseLabel()
                      : '노출 전 · 결제로 지도 노출 필요',
                  isExposed: _hasActivatedJobPins,
                  onEdit: widget.workplaceReady
                      ? widget.onConfigurePins
                      : null,
                )
              else
                _ServiceOutlineButton(
                  onPressed: widget.workplaceReady
                      ? widget.onConfigurePins
                      : null,
                  icon: Icons.add_location_alt_outlined,
                  label: '일자리 알림핀 추가',
                ),
              if (!widget.workplaceReady)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '근무지를 먼저 선택해 주세요.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _buildExposurePaymentActions(
                product: '일자리 알림핀',
                enabled: _hasExtraPins && _unactivatedJobPinCount > 0,
                onDirectPay: () => _openJobPinPayment(),
                onRequestPay: () => _openJobPinPayment(
                  preference: CorporatePaymentPreference.request,
                ),
              ),
              if (_hasExtraPins && _unactivatedJobPinCount == 0) ...[
                const SizedBox(height: 8),
                Text(
                  '모든 일자리 알림핀이 지도에 노출 중입니다. 추가 결제가 필요 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShuttlePinExpansion() {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Row(
        children: [
          Icon(
            Icons.directions_bus_filled_outlined,
            size: 20,
            color: _hasShuttleRoute
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '정류장 표시핀',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_hasShuttleRoute)
            _ExposureStepBadge(
              isExposed: _shuttleExposureActive,
              accentColor: AppColors.primary,
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '운영 중인 통근버스의 정류장과 노선도를 지도 상에 직접 표시하여 '
                '모집 효과를 높일 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 10),
              _WalletCreditLabel(
                label: '노출 이용권',
                count: _exposureCredits,
                detailLine: _hasShuttleRoute
                    ? '등록 $_shuttleStopCount핀 · 노출 $_shuttleExposedStopCount핀'
                    : null,
              ),
              const SizedBox(height: 8),
              if (_hasShuttleRoute)
                _ShuttleRouteAddedRow(
                  routeName: _shuttleRouteName ?? '…',
                  pinCount: _shuttleStopCount,
                  onEdit: _openShuttlePinEditor,
                  exposureActive: _shuttleExposureActive,
                  phaseLabel: _shuttleExposureActive
                      ? _shuttleExposurePhaseLabel()
                      : '노출 전 · 결제로 지도 노출 필요',
                )
              else
                _ServiceOutlineButton(
                  onPressed: _openShuttlePinEditor,
                  icon: Icons.add_road_outlined,
                  label: '정류장 표시핀 추가',
                ),
              const SizedBox(height: 8),
              _buildExposurePaymentActions(
                product: '정류장 표시핀',
                enabled: _needsShuttlePayment,
                onDirectPay: () => _openShuttlePayment(),
                onRequestPay: () => _openShuttlePayment(
                  preference: CorporatePaymentPreference.request,
                ),
              ),
              if (_hasShuttleRoute && !_needsShuttlePayment) ...[
                const SizedBox(height: 8),
                Text(
                  '모든 정류장 표시핀이 지도에 노출 중입니다. 추가 결제가 필요 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ] else if (_hasShuttleRoute &&
                  _shuttleUnpaidStopCount > 0 &&
                  _shuttleExposedStopCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '노출 중인 정류장은 잠금 상태입니다. 새로 추가한 정류장만 결제하면 됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPushTicketSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            const UrgentHireBadge(height: 16, fontSize: 9.5),
            const SizedBox(width: 6),
            const Text(
              '급구알림 (PUSH 이용권)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '지도에 노출된 일자리 알림핀·정류장 표시핀 주변 '
          '${PushPackageCatalog.pushRadiusLabel} 반경 이용자에게 '
          '모집 공고 PUSH를 보낼 수 있습니다.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 10),
        _PushReadinessSummary(
          pushCredits: _pushTicketCredits,
          eligibleLocations: _pushEligibleLocationCount,
          needsJobPinPayment: _hasExtraPins && !_hasActivatedJobPins,
          needsShuttlePayment: _needsShuttlePayment,
          onJobPinPayment:
              _hasExtraPins ? () => _openJobPinPayment() : null,
          onShuttlePayment:
              _hasShuttleRoute ? () => _openShuttlePayment() : null,
          jobPinPayLabel: _showDualPayment
              ? _delegateInfo!.directPayLabel('일자리 알림핀')
              : '일자리 알림핀 결제',
          shuttlePayLabel: _showDualPayment
              ? _delegateInfo!.directPayLabel('정류장 표시핀')
              : '정류장 표시핀 결제',
        ),
        const SizedBox(height: 10),
        _buildExposurePaymentActions(
          product: 'PUSH 이용권',
          enabled: _hasExtraPins || _hasShuttleRoute,
          onDirectPay: _openPushTicketPurchase,
          onRequestPay: _requestPushTicketPayment,
        ),
        const SizedBox(height: 8),
        _ServiceOutlineButton(
          onPressed: _canUsePushTicket ? _openPushTicketUse : null,
          icon: Icons.send_outlined,
          label: 'PUSH 이용권 사용',
        ),
        if (_pushTicketCredits > 0 && !_canUsePushTicket)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PushBlockedHint(
              needsJobPinPayment: _hasExtraPins && !_hasActivatedJobPins,
              needsShuttlePayment: _needsShuttlePayment,
              onJobPinPayment:
                  _hasExtraPins ? () => _openJobPinPayment() : null,
              onShuttlePayment:
                  _hasShuttleRoute ? () => _openShuttlePayment() : null,
              jobPinPayLabel: _showDualPayment
                  ? _delegateInfo!.directPayLabel('일자리 알림핀')
                  : '일자리 알림핀 결제',
              shuttlePayLabel: _showDualPayment
                  ? _delegateInfo!.directPayLabel('정류장 표시핀')
                  : '정류장 표시핀 결제',
            ),
          ),
      ],
    );
  }
}

class _PaidServiceCategoryCard extends StatelessWidget {
  const _PaidServiceCategoryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.searchBarBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: child,
        ),
      ),
    );
  }
}

class _WalletCreditLabel extends StatelessWidget {
  const _WalletCreditLabel({
    required this.label,
    required this.count,
    this.detailLine,
  });

  final String label;
  final int count;
  final String? detailLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label $count회 보유',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary.withValues(alpha: 0.95),
          ),
        ),
        if (detailLine != null) ...[
          const SizedBox(height: 2),
          Text(
            detailLine!,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.88),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExposureStepBadge extends StatelessWidget {
  const _ExposureStepBadge({
    required this.isExposed,
    required this.accentColor,
  });

  final bool isExposed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final label = isExposed ? '노출 중' : '등록됨';
    final bg = isExposed
        ? accentColor.withValues(alpha: 0.14)
        : AppColors.textSecondary.withValues(alpha: 0.1);
    final fg = isExposed ? accentColor : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _ConfiguredServiceRow extends StatelessWidget {
  const _ConfiguredServiceRow({
    required this.primaryLabel,
    required this.phaseLabel,
    required this.isExposed,
    required this.onEdit,
  });

  final String primaryLabel;
  final String phaseLabel;
  final bool isExposed;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.searchBarBorder),
              color: AppColors.background.withValues(alpha: 0.45),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phaseLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: isExposed
                        ? AppColors.primary.withValues(alpha: 0.95)
                        : AppColors.primary.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            maximumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Icon(Icons.settings_outlined, size: 20),
        ),
      ],
    );
  }
}

class _ShuttleRouteAddedRow extends StatelessWidget {
  const _ShuttleRouteAddedRow({
    required this.routeName,
    required this.pinCount,
    required this.onEdit,
    this.exposureActive = false,
    required this.phaseLabel,
  });

  final String routeName;
  final int pinCount;
  final VoidCallback onEdit;
  final bool exposureActive;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    return _ConfiguredServiceRow(
      primaryLabel: pinCount > 0 && routeName.contains(',')
          ? '정류장 표시핀 등록 완료\n노선 $routeName · $pinCount핀'
          : '정류장 표시핀 등록 완료\n노선: $routeName · $pinCount핀',
      phaseLabel: phaseLabel,
      isExposed: exposureActive,
      onEdit: onEdit,
    );
  }
}

class _PushReadinessSummary extends StatelessWidget {
  const _PushReadinessSummary({
    required this.pushCredits,
    required this.eligibleLocations,
    required this.needsJobPinPayment,
    required this.needsShuttlePayment,
    this.onJobPinPayment,
    this.onShuttlePayment,
    this.jobPinPayLabel = '일자리 알림핀 결제',
    this.shuttlePayLabel = '정류장 표시핀 결제',
  });

  final int pushCredits;
  final int eligibleLocations;
  final bool needsJobPinPayment;
  final bool needsShuttlePayment;
  final VoidCallback? onJobPinPayment;
  final VoidCallback? onShuttlePayment;
  final String jobPinPayLabel;
  final String shuttlePayLabel;

  @override
  Widget build(BuildContext context) {
    final canSend = pushCredits > 0 && eligibleLocations > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: canSend
            ? AppColors.primary.withValues(alpha: 0.08)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canSend
              ? AppColors.primary.withValues(alpha: 0.28)
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PUSH 이용권 $pushCredits회 보유 · 발송 가능 위치 $eligibleLocations곳',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: canSend
                  ? AppColors.primary.withValues(alpha: 0.95)
                  : Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canSend
                ? '노출된 위치를 선택해 PUSH를 보낼 수 있습니다.'
                : '① 알림핀/표시핀 추가 → ② 알림핀/표시핀 결제(노출) → '
                    '③ PUSH발송권 결제 후 발송 순서입니다.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '노출 상태가 종료된 알림핀/표시핀에는 PUSH 알림을 발송할 수 없습니다.',
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.78),
            ),
          ),
          if (!canSend &&
              (needsJobPinPayment || needsShuttlePayment)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (needsJobPinPayment)
                  _QuickActionChip(
                    label: jobPinPayLabel,
                    onPressed: onJobPinPayment,
                  ),
                if (needsShuttlePayment)
                  _QuickActionChip(
                    label: shuttlePayLabel,
                    onPressed: onShuttlePayment,
                    accent: AppColors.primary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PushBlockedHint extends StatelessWidget {
  const _PushBlockedHint({
    required this.needsJobPinPayment,
    required this.needsShuttlePayment,
    this.onJobPinPayment,
    this.onShuttlePayment,
    this.jobPinPayLabel = '일자리 알림핀 결제',
    this.shuttlePayLabel = '정류장 표시핀 결제',
  });

  final bool needsJobPinPayment;
  final bool needsShuttlePayment;
  final VoidCallback? onJobPinPayment;
  final VoidCallback? onShuttlePayment;
  final String jobPinPayLabel;
  final String shuttlePayLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PUSH 이용권은 있지만 발송 가능 위치가 없습니다. '
          '② 알림핀/표시핀 결제(노출)를 먼저 완료해 주세요.',
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        if (needsJobPinPayment || needsShuttlePayment) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (needsJobPinPayment)
                _QuickActionChip(
                  label: jobPinPayLabel,
                  onPressed: onJobPinPayment,
                ),
              if (needsShuttlePayment)
                _QuickActionChip(
                  label: shuttlePayLabel,
                  onPressed: onShuttlePayment,
                  accent: AppColors.primary,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.onPressed,
    this.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return ActionChip(
      onPressed: onPressed,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ServiceOutlineButton extends StatelessWidget {
  const _ServiceOutlineButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: CorporateServiceActionStyle.setupOutlined(),
    );
  }
}

class _ServicePaymentButton extends StatelessWidget {
  const _ServicePaymentButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: CorporateServiceActionStyle.paymentFilled(),
    );
  }
}
