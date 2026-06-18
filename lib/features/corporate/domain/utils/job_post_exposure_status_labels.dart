import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 카드 — 노출·확장 서비스 상태 문구
abstract final class JobPostExposureStatusLabels {
  static const workplaceActive = '근무지 주변 · 현재 이용중';
  static const workplaceInactive = '근무지 주변 · 현재\n미이용중';

  static String shuttlePinCompact(CorporateJobPost post) {
    final hasShuttle = post.effectiveLinkedCommuteRouteIds.isNotEmpty;
    final shuttleStopCount = post.registeredShuttleStopCount;
    final shuttleActive = hasShuttle && post.hasShuttleRouteOverlay;
    final extraPinCount =
        (post.notificationSettings?.basePoints.length ?? 0) - 1;
    final extraPins = extraPinCount > 0;
    final pinActivated = _hasActivatedRecruitmentPins(post);

    if (!hasShuttle && !extraPins) {
      return '통근버스 · 알림핀\n미이용중';
    }

    final shuttleLabel = !hasShuttle
        ? '통근버스 미이용'
        : shuttleStopCount > 0
            ? shuttleActive
                ? '${PushPackageCatalog.shuttlePinProductName} $shuttleStopCount · 이용중'
                : '${PushPackageCatalog.shuttlePinProductName} $shuttleStopCount · 설정됨'
            : shuttleActive
                ? '통근버스 이용중'
                : '통근버스 노선등록';
    final pinLabel = !extraPins
        ? '알림핀 미이용'
        : pinActivated
            ? '${PushPackageCatalog.jobPinProductName} $extraPinCount · 이용중'
            : '${PushPackageCatalog.jobPinProductName} $extraPinCount · 설정됨';

    return '$shuttleLabel · $pinLabel';
  }

  static bool _hasActivatedRecruitmentPins(CorporateJobPost post) {
    final points = post.notificationSettings?.basePoints ?? const [];
    for (var i = 1; i < points.length; i++) {
      if (points[i].exposureActivated) return true;
    }
    return false;
  }
}
