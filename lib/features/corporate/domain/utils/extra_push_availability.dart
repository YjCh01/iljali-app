import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_target_resolver.dart';

enum ExtraPushDisableReason {
  none,
  noTargets,
}

/// 공고 카드 — PUSH 보내기 버튼 활성/문구
class ExtraPushAvailability {
  const ExtraPushAvailability({
    required this.enabled,
    required this.subtitle,
    required this.reason,
    this.targetCount = 0,
  });

  final bool enabled;
  final String subtitle;
  final ExtraPushDisableReason reason;
  final int targetCount;

  /// PUSH 보내기 버튼 하단 — PUSH권 단가 (알림핀과 분리)
  String? get recruitButtonCostLabel {
    if (!canDispatchRecruit) return null;
    return PushTicketCatalog.unitPriceLabel;
  }

  bool get suggestsPurchase => false;

  bool get needsExposureSetup => reason == ExtraPushDisableReason.noTargets;

  bool get canDispatchRecruit => reason == ExtraPushDisableReason.none;

  String buttonLabel({String recruitLabel = 'PUSH 보내기'}) {
    if (needsExposureSetup) return '알림핀·거점';
    return recruitLabel;
  }

  static ExtraPushAvailability resolve({
    required CorporateJobPost post,
    EmployerPushWallet? wallet,
  }) {
    final syncTargets = PushDispatchTargetResolver.resolveSync(post: post);
    final hasShuttle = post.commuteRouteId?.trim().isNotEmpty == true;
    final targetCount = syncTargets.length + (hasShuttle ? 1 : 0);

    if (syncTargets.isEmpty && !hasShuttle) {
      return const ExtraPushAvailability(
        enabled: false,
        reason: ExtraPushDisableReason.noTargets,
        subtitle: '발송 대상 없음 · 알림핀·거점 또는 셔틀 노선을 설정하세요',
      );
    }

    final ticketLabel = wallet?.pushTicketDetailLabel ?? PushTicketCatalog.priceLine;
    final exposureCount = syncTargets.length;
    final shuttleHint = hasShuttle ? ' · 셔틀 정류장 선택 가능' : '';

    return ExtraPushAvailability(
      enabled: true,
      reason: ExtraPushDisableReason.none,
      targetCount: targetCount,
      subtitle: exposureCount > 0
          ? '발송 대상 $exposureCount곳$shuttleHint · $ticketLabel'
          : '셔틀 정류장에서 발송 대상 선택 · $ticketLabel',
    );
  }
}
