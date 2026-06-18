import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

/// 셔틀 노선·정류장 지도 오버레이 유료 활성화 결과
class ShuttleOverlayActivationResult {
  const ShuttleOverlayActivationResult._({
    required this.success,
    this.message,
    this.updatedPost,
    this.needsShop = false,
    this.includedPushTarget,
  });

  final bool success;
  final String? message;
  final CorporateJobPost? updatedPost;
  final bool needsShop;

  /// 노출+PUSH 번들 사용 시 발송할 정류장 (호출측에서 PUSH 진행)
  final PushDispatchTarget? includedPushTarget;

  factory ShuttleOverlayActivationResult.success(
    CorporateJobPost post, {
    PushDispatchTarget? includedPushTarget,
  }) {
    return ShuttleOverlayActivationResult._(
      success: true,
      updatedPost: post,
      includedPushTarget: includedPushTarget,
      message: includedPushTarget == null
          ? '구직자 지도에 노선·정류장이 노출됩니다.'
          : '지도 노출이 활성화되었습니다. PUSH 발송 화면으로 이동합니다.',
    );
  }

  factory ShuttleOverlayActivationResult.fail(
    String message, {
    bool needsShop = false,
  }) {
    return ShuttleOverlayActivationResult._(
      success: false,
      message: message,
      needsShop: needsShop,
    );
  }
}

/// 공고에 연결된 셔틀 노선의 지도 오버레이를 유료 활성화
class ShuttleOverlayActivationService {
  ShuttleOverlayActivationService({
    PushWalletService? walletService,
    ExposureActivationService? exposureActivationService,
    CorporateJobPostLocalDataSource? dataSource,
  })  : _exposureActivationService =
            exposureActivationService ?? ExposureActivationService(),
        _dataSource =
            dataSource ?? const CorporateJobPostLocalDataSourceImpl();

  final ExposureActivationService _exposureActivationService;
  final CorporateJobPostLocalDataSource _dataSource;

  Future<ShuttleOverlayActivationResult> activate({
    required CorporateJobPost post,
    required CorporateMemberProfile profile,
    required ExposureActivationCreditMode mode,
    CommuteRoute? commuteRoute,
  }) async {
    final routeId = post.commuteRouteId?.trim();
    if (routeId == null || routeId.isEmpty) {
      return ShuttleOverlayActivationResult.fail(
        '먼저 셔틀 노선을 연결해 주세요.',
      );
    }

    if (post.hasShuttleRouteOverlay) {
      return ShuttleOverlayActivationResult.fail(
        '이미 지도 노선·정류장이 활성화되어 있습니다.',
      );
    }

    final consume = await _exposureActivationService.consumeCredit(
      profile: profile,
      mode: mode,
    );
    if (!consume.success) {
      return ShuttleOverlayActivationResult.fail(
        consume.message ?? '이용권이 부족합니다. 노출·PUSH 상품을 구매해 주세요.',
        needsShop: true,
      );
    }

    final updated = post.copyWith(hasShuttleRouteOverlay: true);
    await _dataSource.updateJobPost(updated);

    PushDispatchTarget? pushTarget;
    if (mode == ExposureActivationCreditMode.exposureWithPush) {
      pushTarget = _resolveShuttlePushTarget(commuteRoute);
    }

    return ShuttleOverlayActivationResult.success(
      updated,
      includedPushTarget: pushTarget,
    );
  }

  PushDispatchTarget? _resolveShuttlePushTarget(CommuteRoute? route) {
    if (route == null || route.stops.isEmpty) return null;
    final stop = route.stops.first;
    return PushDispatchTarget(
      id: 'stop_${stop.id}',
      kind: PushDispatchTargetKind.shuttleStop,
      title: stop.label,
      subtitle: '${route.routeName} · 정류장',
      coordinate: stop.coordinate,
      radiusMeters: PushPackageCatalog.packagePushRadiusM,
      shuttleStopId: stop.id,
      routeName: route.routeName,
    );
  }
}
