import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// PUSH 발송 대상 유형 — 각 1곳 = PUSH권 1회
enum PushDispatchTargetKind {
  /// 무료 등록 공고의 사업소재지 · 근무지 반경 700m
  workplace,

  /// 유료 활성화된 알림핀 거점
  notificationPin,

  /// 셔틀 노선의 개별 정류장 (노선 전체 아님)
  shuttleStop,
}

extension PushDispatchTargetKindX on PushDispatchTargetKind {
  String get sectionTitle => switch (this) {
        PushDispatchTargetKind.workplace => '근무지',
        PushDispatchTargetKind.notificationPin => '일자리 알림핀',
        PushDispatchTargetKind.shuttleStop => '셔틀 정류장',
      };

  String get iconHint => switch (this) {
        PushDispatchTargetKind.workplace =>
          '근무지 주변 ${PushPackageCatalog.pushRadiusLabel}',
        PushDispatchTargetKind.notificationPin =>
          '알림핀 주변 ${PushPackageCatalog.pushRadiusLabel}',
        PushDispatchTargetKind.shuttleStop =>
          '정류장 주변 ${PushPackageCatalog.pushRadiusLabel}',
      };
}

/// PUSH 1회 발송 대상 1곳
class PushDispatchTarget {
  const PushDispatchTarget({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coordinate,
    required this.radiusMeters,
    this.basePointId,
    this.shuttleStopId,
    this.routeName,
    this.routeId,
    this.exposureActivated = false,
  });

  final String id;
  final PushDispatchTargetKind kind;
  final String title;
  final String subtitle;
  final GeoCoordinate coordinate;
  final int radiusMeters;
  final String? basePointId;
  final String? shuttleStopId;
  final String? routeName;
  final String? routeId;
  final bool exposureActivated;

  String get displayLine => '$title · $subtitle';

  String get radiusLabel {
    if (radiusMeters <= 0) return '위치만';
    if (radiusMeters == PushPackageCatalog.freePushRadiusM ||
        radiusMeters == PushPackageCatalog.packagePushRadiusM) {
      return PushPackageCatalog.pushRadiusLabel;
    }
    return '${radiusMeters}m';
  }
}
