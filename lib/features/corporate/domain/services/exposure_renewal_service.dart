import 'package:flutter/material.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/exposure_renewal_notice_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/utils/corporate_job_post_scope.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/core/sync/job_post_sync_service.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_navigation_helper.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_renewal_policy.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';

class ExposureRenewalResult {
  const ExposureRenewalResult({
    required this.success,
    this.message,
    this.needsShop = false,
  });

  final bool success;
  final String? message;
  final bool needsShop;
}

/// 만료·만료 예정 노출 연장 — 체크박스 선택 후 결제
class ExposureRenewalService {
  ExposureRenewalService({
    CorporateJobPostLocalDataSource? jobPostDataSource,
    PushWalletService? walletService,
    ExposureActivationService? exposureActivationService,
  })  : _jobPostDataSource =
            jobPostDataSource ?? const CorporateJobPostLocalDataSourceImpl(),
        _walletService = walletService ?? PushWalletService(),
        _exposureActivationService =
            exposureActivationService ?? ExposureActivationService();

  final CorporateJobPostLocalDataSource _jobPostDataSource;
  final PushWalletService _walletService;
  final ExposureActivationService _exposureActivationService;

  Future<ExposureRenewalResult> renewSelected({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required CorporateJobPost post,
    required Map<String, CommuteRoute> routesById,
    required Set<String> selectedCandidateIds,
    CorporatePaymentPreference paymentPreference =
        CorporatePaymentPreference.auto,
  }) async {
    if (selectedCandidateIds.isEmpty) {
      return const ExposureRenewalResult(
        success: false,
        message: '연장할 핀·정류장을 선택해 주세요.',
      );
    }

    final paidBlocked = profile.paidServicesBlockedReason;
    if (paidBlocked != null) {
      return ExposureRenewalResult(success: false, message: paidBlocked);
    }

    final candidates = ExposureRenewalPolicy.collectForPost(
      post: post,
      routesById: routesById,
    );
    final selected = candidates
        .where((c) => selectedCandidateIds.contains(c.id))
        .toList();
    if (selected.isEmpty) {
      return const ExposureRenewalResult(
        success: false,
        message: '연장 가능한 항목이 없습니다.',
      );
    }

    final jobPinIndices = [
      for (final c in selected)
        if (c.kind == ExposureRenewalCandidateKind.jobPin) c.pointIndex!,
    ];
    final shuttleByRoute = <String, Set<String>>{};
    for (final c in selected) {
      if (c.kind != ExposureRenewalCandidateKind.shuttleStop) continue;
      shuttleByRoute
          .putIfAbsent(c.routeId!, () => <String>{})
          .add(c.stopId!);
    }

    final totalChargeCount = jobPinIndices.length +
        shuttleByRoute.values.fold<int>(0, (sum, ids) => sum + ids.length);
    if (totalChargeCount == 0) {
      return const ExposureRenewalResult(
        success: false,
        message: '연장할 항목이 없습니다.',
      );
    }

    var paidCount = 0;
    var pendingCount = totalChargeCount;

    // 1) 보유 이용권 소진
    while (pendingCount > 0) {
      if (!context.mounted) {
        return const ExposureRenewalResult(success: false);
      }
      final wallet = await _walletService.loadWallet(profile);
      if (wallet.packageCredits <= 0) break;

      final mode = await _exposureActivationService.pickCreditMode(
        context,
        wallet: wallet,
        title: '노출 연장',
        subtitle: '선택 ${pendingCount}곳 · D+1 23:59:59 연장',
      );
      if (!context.mounted || mode == null) break;

      final consumed = await _exposureActivationService.consumeCredit(
        profile: profile,
        mode: mode,
      );
      if (!consumed.success) break;
      paidCount++;
      pendingCount--;
    }

    // 2) 남은 금액 — 보유금+PG (ExposureRenewal은 jobPinExposure로 통합)
    if (pendingCount > 0) {
      if (!context.mounted) {
        return const ExposureRenewalResult(success: false);
      }

      final bundle = PushPaymentBundle(
        radiusTier: PushRadiusTier.standard1km,
        pointTier: DesignatedPointTier.onePoint,
        spotCount: pendingCount,
        isExtraPush: true,
        extraPushFeeKrw:
            pendingCount * PushPackageCatalog.exposureUnitPriceKrw,
        paymentKind: JobPostPaymentRequestKind.jobPinExposure,
      );

      final pay = await CorporatePaymentNavigationHelper().payOrRequest(
        context: context,
        bundle: bundle,
        kind: JobPostPaymentRequestKind.jobPinExposure,
        jobPostId: post.id,
        jobTitle: post.title,
        preference: paymentPreference,
      );
      if (!context.mounted) {
        return const ExposureRenewalResult(success: false);
      }
      if (pay.isRequestSent) {
        return ExposureRenewalResult(
          success: false,
          message: pay.message ?? '결제 담당자에게 요청을 보냈습니다.',
        );
      }
      if (!pay.isPaid) {
        return ExposureRenewalResult(
          success: false,
          message: pay.message ?? '결제가 취소되었습니다.',
        );
      }
      paidCount += pendingCount;
    }

    if (paidCount < totalChargeCount) {
      return const ExposureRenewalResult(
        success: false,
        message: '연장 결제가 완료되지 않았습니다.',
      );
    }

    // 3) 노출 시각 갱신
    var updatedPost = post;
    final settings = post.notificationSettings;
    if (settings != null && jobPinIndices.isNotEmpty) {
      final points = List<PushNotificationBasePoint>.from(settings.basePoints);
      for (final index in jobPinIndices) {
        if (index < 0 || index >= points.length) continue;
        points[index] = ExposureSlotPolicy.renewActivation(points[index]);
      }
      updatedPost = updatedPost.copyWith(
        notificationSettings: settings.copyWith(basePoints: points),
      );
    }

    if (shuttleByRoute.isNotEmpty) {
      final paidByRoute = Map<String, List<String>>.from(
        updatedPost.shuttlePaidStopIdsByRoute,
      );
      for (final entry in shuttleByRoute.entries) {
        final merged = <String>{
          ...?paidByRoute[entry.key],
          ...entry.value,
        };
        paidByRoute[entry.key] = merged.toList(growable: false);
      }
      updatedPost = updatedPost.copyWith(
        hasShuttleRouteOverlay: true,
        shuttleExposurePaidAt: DateTime.now(),
        shuttlePaidStopIdsByRoute: paidByRoute,
      );
    }

    final now = DateTime.now();
    updatedPost = updatedPost.copyWith(
      expiresAt: JobPostValidity.expiresAtFromRegistration(now),
      status: updatedPost.status == CorporateJobPostStatus.closed
          ? updatedPost.status
          : CorporateJobPostStatus.recruiting,
    );

    await _jobPostDataSource.updateJobPost(
      updatedPost,
      ownerCompanyKey: profile.companyKey,
    );
    await JobPostSyncService().pushPostUpdate(updatedPost);

    final noticeRepo = await ExposureRenewalNoticeRepository.create();
    await noticeRepo.clearDismissed(
      companyKey: profile.companyKey,
      jobPostId: post.id,
    );

    return ExposureRenewalResult(
      success: true,
      message:
          '선택한 ${totalChargeCount}곳 노출이 D+1 23:59:59까지 연장되었습니다.',
    );
  }
}

/// 채팅 탭 공식 알림 — 만료·만료 예정 공고 스캔
class ExposureRenewalNoticeService {
  ExposureRenewalNoticeService({
    CorporateJobPostLocalDataSource? jobPostDataSource,
    ExposureRenewalNoticeRepository? noticeRepository,
  })  : _jobPostDataSource =
            jobPostDataSource ?? const CorporateJobPostLocalDataSourceImpl(),
        _noticeRepositoryFuture = noticeRepository != null
            ? Future.value(noticeRepository)
            : ExposureRenewalNoticeRepository.create();

  final CorporateJobPostLocalDataSource _jobPostDataSource;
  final Future<ExposureRenewalNoticeRepository> _noticeRepositoryFuture;

  Future<List<CorporateChatRoom>> fetchNoticeRooms({
    required String companyKey,
  }) async {
    if (companyKey.isEmpty) return const [];

    final noticeRepo = await _noticeRepositoryFuture;
    final dismissed = await noticeRepo.loadDismissedPostIds(companyKey);
    final posts = await _jobPostDataSource.fetchJobPosts();
    final routeRepo = await CommuteRouteRepository.create();
    final routesById = {
      for (final route in await routeRepo.loadAllActive()) route.id: route,
    };

    final rooms = <CorporateChatRoom>[];
    for (final post in posts) {
      if (!CorporateJobPostScope.belongsToCompany(post, companyKey)) continue;
      if (post.status == CorporateJobPostStatus.closed) continue;
      if (dismissed.contains(post.id)) continue;

      final candidates = ExposureRenewalPolicy.collectForPost(
        post: post,
        routesById: routesById,
      );
      if (candidates.isEmpty) continue;

      final expiredCount = candidates
          .where((c) => c.urgency == ExposureRenewalUrgency.expired)
          .length;
      final soonCount = candidates.length - expiredCount;
      final pinCount = candidates
          .where((c) => c.kind == ExposureRenewalCandidateKind.jobPin)
          .length;
      final stopCount = candidates.length - pinCount;

      final parts = <String>[];
      if (pinCount > 0) parts.add('알림핀 $pinCount곳');
      if (stopCount > 0) parts.add('표시핀 $stopCount곳');
      final scope = parts.join(' · ');

      final headline = expiredCount > 0
          ? '「${post.title}」 지도 노출이 종료되었습니다.'
          : '「${post.title}」 노출이 곧 종료됩니다.';

      final detail = expiredCount > 0 && soonCount > 0
          ? '$scope · 종료 $expiredCount · 임박 $soonCount'
          : scope;

      rooms.add(
        CorporateChatRoom(
          id: 'exposure_renewal:${post.id}',
          applicantName: '일자리 공식 알림',
          jobTitle: post.title,
          lastMessage: '$headline $detail',
          updatedAtLabel: '방금',
          unreadCount: 1,
          kind: CorporateChatRoomKind.officialNotice,
          fullMessageBody:
              '$headline\n\n$detail\n\n같은 조건으로 이어서 노출할까요?\n'
              '아래 「연장하기」에서 연장할 핀·정류장을 선택해 결제할 수 있습니다.',
          jobPostId: post.id,
        ),
      );
    }

    rooms.sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    return rooms;
  }

  Future<void> dismissNotice({
    required String companyKey,
    required String jobPostId,
  }) async {
    final repo = await _noticeRepositoryFuture;
    await repo.markDismissed(companyKey: companyKey, jobPostId: jobPostId);
  }
}
