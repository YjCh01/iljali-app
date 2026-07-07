import 'package:flutter/material.dart';
import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_navigation_helper.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_source.dart';
import 'package:map/features/corporate/domain/services/promo_exposure_activation_helper.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

class ShuttleStopActivationResult {
  const ShuttleStopActivationResult({
    required this.success,
    this.updatedStops,
    this.updatedStopsByRouteId,
    this.message,
    this.needsShop = false,
  });

  final bool success;
  final List<CommuteRouteStop>? updatedStops;
  final Map<String, List<CommuteRouteStop>>? updatedStopsByRouteId;
  final String? message;
  final bool needsShop;
}

typedef ShuttleRouteStopSelection = ({
  String routeId,
  List<CommuteRouteStop> stops,
  Set<String> selectedStopIds,
});

/// 정류장 표시핀 — 선택 정류장별 노출 활성화
class ShuttleStopActivationService {
  ShuttleStopActivationService({
    PushWalletService? walletService,
    ExposureActivationService? exposureActivationService,
    CorporateJobPostLocalDataSource? jobPostDataSource,
    PromoExposureActivationHelper? promoHelper,
  })  : _walletService = walletService ?? PushWalletService(),
        _exposureActivationService =
            exposureActivationService ?? ExposureActivationService(),
        _jobPostDataSource =
            jobPostDataSource ?? const CorporateJobPostLocalDataSourceImpl(),
        _promoHelper = promoHelper ?? PromoExposureActivationHelper();

  final PushWalletService _walletService;
  final ExposureActivationService _exposureActivationService;
  final CorporateJobPostLocalDataSource _jobPostDataSource;
  final PromoExposureActivationHelper _promoHelper;

  Future<ShuttleStopActivationResult> activateSelected({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required List<CommuteRouteStop> stops,
    required Set<String> selectedStopIds,
    CorporatePaymentPreference paymentPreference =
        CorporatePaymentPreference.auto,
  }) {
    return activateSelectedBatch(
      context: context,
      profile: profile,
      routeSelections: [
        (
          routeId: '_single',
          stops: stops,
          selectedStopIds: selectedStopIds,
        ),
      ],
      paymentPreference: paymentPreference,
    ).then(
      (batch) => ShuttleStopActivationResult(
        success: batch.success,
        updatedStops: batch.updatedStopsByRouteId?['_single'],
        updatedStopsByRouteId: batch.updatedStopsByRouteId,
        message: batch.message,
        needsShop: batch.needsShop,
      ),
    );
  }

  Future<ShuttleStopActivationResult> activateSelectedBatch({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required List<ShuttleRouteStopSelection> routeSelections,
    CorporatePaymentPreference paymentPreference =
        CorporatePaymentPreference.auto,
    bool billAllSelected = false,
  }) async {
    if (routeSelections.isEmpty ||
        routeSelections.every((s) => s.selectedStopIds.isEmpty)) {
      return const ShuttleStopActivationResult(
        success: false,
        message: '노출할 정류장을 선택해 주세요.',
      );
    }

    final updatedByRouteId = <String, List<CommuteRouteStop>>{
      for (final selection in routeSelections)
        selection.routeId: List<CommuteRouteStop>.from(selection.stops),
    };

    final pending = <({String routeId, int index})>[];
    for (final selection in routeSelections) {
      final updated = updatedByRouteId[selection.routeId]!;
      for (var i = 0; i < updated.length; i++) {
        if (!selection.selectedStopIds.contains(updated[i].id)) continue;
        if (ShuttleRouteStopPolicy.isWorkplaceStop(updated[i])) continue;
        if (!billAllSelected && updated[i].exposureActivated) continue;
        pending.add((routeId: selection.routeId, index: i));
      }
    }

    if (pending.isEmpty) {
      return const ShuttleStopActivationResult(
        success: false,
        message: '선택한 정류장은 이미 노출 중입니다.',
      );
    }

    if (!context.mounted) {
      return const ShuttleStopActivationResult(success: false);
    }

    if (await FreeExposureLaunchPolicy.isActive()) {
      final quota = await _promoHelper.tryConsume(
        companyKey: profile.companyKey,
        count: pending.length,
      );
      if (!quota.success) {
        return ShuttleStopActivationResult(
          success: false,
          message: quota.message,
        );
      }
      for (final target in pending) {
        final routeStops = updatedByRouteId[target.routeId]!;
        routeStops[target.index] =
            _promoHelper.lockShuttleStopPromo(routeStops[target.index]);
      }
      final left = quota.remainingThisMonth;
      final suffix = left == null ? '' : ' (이번 달 무료 $left회 남음)';
      return ShuttleStopActivationResult(
        success: true,
        updatedStopsByRouteId: updatedByRouteId,
        message: '${FreeExposureLaunchPolicy.promoActivationMessage}$suffix',
      );
    }

    ExposureActivationCreditMode? preferredMode;
    var remaining = List<({String routeId, int index})>.from(pending);

    while (remaining.isNotEmpty) {
      if (!context.mounted) {
        return ShuttleStopActivationResult(
          success: false,
          updatedStopsByRouteId: updatedByRouteId,
        );
      }

      final wallet = await _walletService.loadWallet(profile);
      if (wallet.packageCredits <= 0) break;

      final mode = preferredMode ??
          await _exposureActivationService.pickCreditMode(
            context,
            wallet: wallet,
            title: '정류장 표시핀',
            subtitle: '선택한 정류장 ${remaining.length}곳을 구직자 지도에 노출합니다.',
          );
      if (!context.mounted) {
        return ShuttleStopActivationResult(
          success: false,
          updatedStopsByRouteId: updatedByRouteId,
        );
      }
      if (mode == null) break;

      preferredMode = mode;
      final consumed = await _exposureActivationService.consumeCredit(
        profile: profile,
        mode: mode,
      );
      if (!consumed.success) break;

      final target = remaining.removeAt(0);
      final routeStops = updatedByRouteId[target.routeId]!;
      routeStops[target.index] = _promoHelper.lockShuttleStop(
        routeStops[target.index],
        source: ExposureActivationSource.credit,
      );
    }

    if (remaining.isEmpty) {
      return ShuttleStopActivationResult(
        success: true,
        updatedStopsByRouteId: updatedByRouteId,
        message: '선택한 정류장이 구직자 지도에 노출됩니다.',
      );
    }

    if (!context.mounted) {
      return ShuttleStopActivationResult(
        success: false,
        updatedStopsByRouteId: updatedByRouteId,
      );
    }

    final cashCount = remaining.length;
    final bundle = PushPaymentBundle(
      radiusTier: PushRadiusTier.standard1km,
      pointTier: DesignatedPointTier.onePoint,
      spotCount: cashCount,
      isExtraPush: true,
      extraPushFeeKrw: cashCount * PushPackageCatalog.exposureUnitPriceKrw,
      paymentKind: JobPostPaymentRequestKind.shuttleStopExposure,
    );

    final result = await CorporatePaymentNavigationHelper().payOrRequest(
      context: context,
      bundle: bundle,
      kind: JobPostPaymentRequestKind.shuttleStopExposure,
      jobTitle: profile.companyName,
      preference: paymentPreference,
    );
    if (!context.mounted) {
      return ShuttleStopActivationResult(
        success: false,
        updatedStopsByRouteId: updatedByRouteId,
      );
    }

    if (result.isRequestSent) {
      return ShuttleStopActivationResult(
        success: false,
        message: result.message ??
            '결제 담당자에게 요청을 보냈습니다. 승인 후 노출을 활성화해 주세요.',
        updatedStopsByRouteId: updatedByRouteId,
      );
    }

    if (!result.isPaid) {
      return ShuttleStopActivationResult(
        success: false,
        message: result.message ?? '결제가 취소되었습니다.',
        updatedStopsByRouteId: updatedByRouteId,
      );
    }

    for (final target in remaining) {
      final routeStops = updatedByRouteId[target.routeId]!;
      routeStops[target.index] = _promoHelper.lockShuttleStop(
        routeStops[target.index],
        source: ExposureActivationSource.payment,
      );
    }

    return ShuttleStopActivationResult(
      success: true,
      updatedStopsByRouteId: updatedByRouteId,
      message: '선택한 정류장이 구직자 지도에 노출됩니다.',
    );
  }

  /// 공고에 등록된 정류장 결제 — 지도 노출 활성화
  Future<ShuttleStopActivationResult> activateRegisteredStopsForPost({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required String jobPostId,
    required List<ShuttleRouteStopSelection> routeSelections,
    CorporatePaymentPreference paymentPreference =
        CorporatePaymentPreference.auto,
  }) async {
    if (routeSelections.isEmpty ||
        routeSelections.every((s) => s.selectedStopIds.isEmpty)) {
      return const ShuttleStopActivationResult(
        success: false,
        message: '등록된 정류장이 없습니다.',
      );
    }

    final pending = <({String routeId, int index})>[];
    for (final selection in routeSelections) {
      for (var i = 0; i < selection.stops.length; i++) {
        if (!selection.selectedStopIds.contains(selection.stops[i].id)) {
          continue;
        }
        pending.add((routeId: selection.routeId, index: i));
      }
    }

    final post = await _jobPostDataSource.findById(jobPostId.trim());
    if (post == null) {
      return const ShuttleStopActivationResult(
        success: false,
        message: '공고 정보를 찾을 수 없습니다.',
      );
    }

    final chargeableSelections = <ShuttleRouteStopSelection>[];
    for (final selection in routeSelections) {
      final chargeableIds = <String>{};
      for (final id in selection.selectedStopIds) {
        if (!selection.stops.any((stop) => stop.id == id)) continue;
        if (post.isShuttleStopExposureLocked(selection.routeId, id)) {
          continue;
        }
        chargeableIds.add(id);
      }
      if (chargeableIds.isEmpty) continue;
      chargeableSelections.add(
        (
          routeId: selection.routeId,
          stops: selection.stops,
          selectedStopIds: chargeableIds,
        ),
      );
    }

    if (chargeableSelections.isEmpty) {
      return const ShuttleStopActivationResult(
        success: false,
        message: '결제할 정류장이 없습니다. 노출 중인 정류장은 추가만 가능합니다.',
      );
    }

    final batch = await activateSelectedBatch(
      context: context,
      profile: profile,
      routeSelections: chargeableSelections,
      paymentPreference: paymentPreference,
      billAllSelected: !post.isShuttleExposureActive,
    );
    if (batch.success) {
      await _enablePostOverlay(
        jobPostId,
        routeSelections: chargeableSelections,
      );
    }
    return batch;
  }

  Future<void> _enablePostOverlay(
    String jobPostId, {
    required List<ShuttleRouteStopSelection> routeSelections,
  }) async {
    final normalized = jobPostId.trim();
    if (normalized.isEmpty) return;

    final post = await _jobPostDataSource.findById(normalized);
    if (post == null) return;

    final paidByRoute = Map<String, List<String>>.from(
      post.shuttlePaidStopIdsByRoute,
    );
    for (final selection in routeSelections) {
      if (selection.selectedStopIds.isEmpty) continue;
      final merged = <String>{
        ...?paidByRoute[selection.routeId],
        ...selection.selectedStopIds,
      };
      paidByRoute[selection.routeId] = merged.toList(growable: false);
    }

    await _jobPostDataSource.updateJobPost(
      post.copyWith(
        hasShuttleRouteOverlay: true,
        shuttleExposurePaidAt: post.shuttleExposurePaidAt ?? DateTime.now(),
        shuttlePaidStopIdsByRoute: paidByRoute,
      ),
    );
  }

  /// 연결된 공고 — 지도 노출 플래그 동기화 (핀·배지 표시)
  Future<void> syncLinkedJobPostOverlay(String routeId) async {
    final normalized = routeId.trim();
    if (normalized.isEmpty) return;

    final posts = await _jobPostDataSource.fetchJobPosts();
    for (final post in posts) {
      final linked = post.effectiveLinkedCommuteRouteIds;
      final matches =
          linked.contains(normalized) || post.commuteRouteId?.trim() == normalized;
      if (!matches) continue;

      final nextLinked = linked.contains(normalized)
          ? linked
          : [...linked, normalized];
      if (post.hasShuttleRouteOverlay &&
          post.linkedCommuteRouteIds.length == nextLinked.length) {
        continue;
      }
      await _jobPostDataSource.updateJobPost(
        post.copyWith(
          commuteRouteId: nextLinked.first,
          linkedCommuteRouteIds: nextLinked,
          hasShuttleRouteOverlay: true,
        ),
      );
    }
  }
}
