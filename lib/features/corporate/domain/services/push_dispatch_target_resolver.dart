import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// 공고별 PUSH 발송 가능 대상 목록
abstract final class PushDispatchTargetResolver {
  /// 설정·노선 없이 카드 UI용 (셔틀 정류장 제외)
  static List<PushDispatchTarget> resolveSync({required CorporateJobPost post}) {
    return _fromSettings(post.notificationSettings);
  }

  static List<PushDispatchTarget> resolve({
    required CorporateJobPost post,
    CommuteRoute? commuteRoute,
  }) {
    final targets = <PushDispatchTarget>[..._fromSettings(post.notificationSettings)];

    final route = commuteRoute;
    if (route != null && route.stops.isNotEmpty) {
      for (final stop in ShuttleRouteStopPolicy.pushEligibleStops(route.stops)) {
        targets.add(
          PushDispatchTarget(
            id: 'stop_${stop.id}',
            kind: PushDispatchTargetKind.shuttleStop,
            title: stop.label,
            subtitle: '${route.routeName} · 정류장',
            coordinate: stop.coordinate,
            radiusMeters: PushPackageCatalog.packagePushRadiusM,
            shuttleStopId: stop.id,
            routeName: route.routeName,
            routeId: route.id,
            exposureActivated: stop.exposureActivated,
          ),
        );
      }
    }

    return targets;
  }

  static List<PushDispatchTarget> _fromSettings(
    JobPostNotificationSettings? settings,
  ) {
    if (settings == null || settings.basePoints.isEmpty) {
      return const [];
    }

    final targets = <PushDispatchTarget>[];
    for (var i = 0; i < settings.basePoints.length; i++) {
      final point = settings.basePoints[i];
      if (point.radiusMeters <= 0 && i > 0) continue;

      if (i == 0) {
        targets.add(
          PushDispatchTarget(
            id: 'workplace',
            kind: PushDispatchTargetKind.workplace,
            title: '근무지',
            subtitle: point.addressLabel.isNotEmpty
                ? point.addressLabel
                : PushDispatchTargetKind.workplace.iconHint,
            coordinate: point.coordinate,
            radiusMeters: point.radiusMeters > 0
                ? point.radiusMeters
                : PushPackageCatalog.freePushRadiusM,
            basePointId: point.id,
          ),
        );
        continue;
      }

      targets.add(
        PushDispatchTarget(
          id: 'pin_${point.id}',
          kind: PushDispatchTargetKind.notificationPin,
          title: point.addressLabel.isNotEmpty
              ? point.addressLabel
              : '일자리 알림핀 $i',
          subtitle: PushDispatchTargetKind.notificationPin.iconHint,
          coordinate: point.coordinate,
          radiusMeters: point.radiusMeters > 0
              ? point.radiusMeters
              : PushPackageCatalog.packagePushRadiusM,
          basePointId: point.id,
          exposureActivated: point.exposureActivated,
        ),
      );
    }

    return targets;
  }

  static bool hasAnyTarget({
    required CorporateJobPost post,
    bool includeShuttleRoute = true,
  }) {
    if (resolveSync(post: post).isNotEmpty) return true;
    if (!includeShuttleRoute) return false;
    final routeId = post.commuteRouteId?.trim();
    return routeId != null && routeId.isNotEmpty;
  }
}
