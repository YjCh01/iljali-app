import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';

enum ExposureRenewalCandidateKind { jobPin, shuttleStop }

enum ExposureRenewalUrgency { expired, expiringSoon }

/// 연장 대상 핀·정류장
class ExposureRenewalCandidate {
  const ExposureRenewalCandidate({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.urgency,
    this.pointIndex,
    this.routeId,
    this.stopId,
    this.expiresAt,
  });

  final ExposureRenewalCandidateKind kind;
  final String id;
  final String title;
  final String subtitle;
  final ExposureRenewalUrgency urgency;
  final int? pointIndex;
  final String? routeId;
  final String? stopId;
  final DateTime? expiresAt;

  String get urgencyLabel => switch (urgency) {
        ExposureRenewalUrgency.expired => '노출 종료',
        ExposureRenewalUrgency.expiringSoon => '곧 종료',
      };
}

/// 만료·만료 예정 노출 후보 수집
abstract final class ExposureRenewalPolicy {
  static const expiringSoonWindow = Duration(hours: 24);

  static List<ExposureRenewalCandidate> collectForPost({
    required CorporateJobPost post,
    required Map<String, CommuteRoute> routesById,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final candidates = <ExposureRenewalCandidate>[];
    candidates.addAll(_jobPinCandidates(post, clock));
    candidates.addAll(_shuttleCandidates(post, routesById, clock));
    return candidates;
  }

  static List<ExposureRenewalCandidate> _jobPinCandidates(
    CorporateJobPost post,
    DateTime clock,
  ) {
    final settings = post.notificationSettings;
    if (settings == null || settings.basePoints.length <= 1) {
      return const [];
    }

    final out = <ExposureRenewalCandidate>[];
    for (var i = 1; i < settings.basePoints.length; i++) {
      if (!PushWalletCreditPolicy.isRecruitmentZoneIndex(i)) continue;
      final point = settings.basePoints[i];
      if (!point.exposureActivated) continue;

      final urgency = _urgencyForExpiry(point.exposureExpiresAt, clock);
      if (urgency == null) continue;

      out.add(
        ExposureRenewalCandidate(
          kind: ExposureRenewalCandidateKind.jobPin,
          id: 'pin_${point.id}',
          title: ExposurePointLabels.title(i),
          subtitle: point.addressLabel.isNotEmpty
              ? point.addressLabel
              : '일자리 알림핀',
          urgency: urgency,
          pointIndex: i,
          expiresAt: point.exposureExpiresAt,
        ),
      );
    }
    return out;
  }

  static List<ExposureRenewalCandidate> _shuttleCandidates(
    CorporateJobPost post,
    Map<String, CommuteRoute> routesById,
    DateTime clock,
  ) {
    if (!post.hasShuttlePinRegistration) return const [];

    final resolved = post.resolveShuttleExposureMetadata();
    final globalExpires = resolved.shuttleExposureExpiresAt;
    final globalUrgency = _urgencyForExpiry(globalExpires, clock);

    final out = <ExposureRenewalCandidate>[];
    for (final entry in resolved.shuttleRegisteredStopIdsByRoute.entries) {
      final route = routesById[entry.key];
      if (route == null) continue;

      for (final stopId in entry.value) {
        final stop = route.stops.cast<CommuteRouteStop?>().firstWhere(
              (s) => s?.id == stopId,
              orElse: () => null,
            );
        if (stop == null || ShuttleRouteStopPolicy.isWorkplaceStop(stop)) {
          continue;
        }

        final wasPaid = resolved.isShuttleStopExposureLocked(entry.key, stopId) ||
            stop.exposureActivated ||
            (resolved.shuttlePaidStopIdsByRoute[entry.key] ?? const [])
                .contains(stopId);
        if (!wasPaid) continue;

        final currentlyLocked =
            resolved.isShuttleStopExposureLocked(entry.key, stopId);
        final urgency = currentlyLocked
            ? globalUrgency
            : ExposureRenewalUrgency.expired;
        if (urgency == null && currentlyLocked) continue;
        if (!currentlyLocked) {
          out.add(
            ExposureRenewalCandidate(
              kind: ExposureRenewalCandidateKind.shuttleStop,
              id: 'stop_${entry.key}_$stopId',
              title: stop.label,
              subtitle: route.routeName,
              urgency: ExposureRenewalUrgency.expired,
              routeId: entry.key,
              stopId: stopId,
              expiresAt: globalExpires,
            ),
          );
          continue;
        }

        out.add(
          ExposureRenewalCandidate(
            kind: ExposureRenewalCandidateKind.shuttleStop,
            id: 'stop_${entry.key}_$stopId',
            title: stop.label,
            subtitle: route.routeName,
            urgency: urgency!,
            routeId: entry.key,
            stopId: stopId,
            expiresAt: globalExpires,
          ),
        );
      }
    }
    return out;
  }

  static ExposureRenewalUrgency? _urgencyForExpiry(
    DateTime? expiresAt,
    DateTime clock,
  ) {
    if (expiresAt == null) return null;
    if (JobPostValidity.isExpired(expiresAt, clock)) {
      return ExposureRenewalUrgency.expired;
    }
    final remaining = expiresAt.difference(clock);
    if (remaining <= expiringSoonWindow) {
      return ExposureRenewalUrgency.expiringSoon;
    }
    return null;
  }

  static String remainingOrEndedLabel(DateTime? expiresAt, [DateTime? now]) {
    if (expiresAt == null) return 'D+1 23:59:59까지';
    final clock = now ?? DateTime.now();
    if (JobPostValidity.isExpired(expiresAt, clock)) return '노출 종료';
    return ShuttleExposurePolicy.remainingLabel(expiresAt, clock);
  }
}
