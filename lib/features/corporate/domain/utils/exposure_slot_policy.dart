import 'package:map/features/corporate/domain/entities/exposure_activation_source.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

/// 일자리 알림핀·PUSH 어뷰징 방지 — 노출 활성화(잠금 좌표)와 PUSH 발송 자격
abstract final class ExposureSlotPolicy {
  /// 약 5m — 좌표 잠금 비교
  static const coordinateEpsilon = 0.00005;

  static bool coordinatesMatch(GeoCoordinate a, GeoCoordinate b) {
    return (a.latitude - b.latitude).abs() < coordinateEpsilon &&
        (a.longitude - b.longitude).abs() < coordinateEpsilon;
  }

  /// 이용권 소진 후 해당 거점을 노출 활성화·좌표 잠금
  static PushNotificationBasePoint lockActivation(
    PushNotificationBasePoint point, {
    DateTime? paidAt,
    ExposureActivationSource? activationSource,
  }) {
    return point.copyWith(
      exposureActivated: true,
      activationCoordinate: point.coordinate,
      exposurePaidAt: point.exposurePaidAt ?? paidAt ?? DateTime.now(),
      exposureActivationSource: activationSource ?? point.exposureActivationSource,
    );
  }

  /// 만료된 노출 연장 — 결제 시각을 새로 갱신
  static PushNotificationBasePoint renewActivation(
    PushNotificationBasePoint point, {
    DateTime? paidAt,
    ExposureActivationSource? activationSource,
  }) {
    return point.copyWith(
      exposureActivated: true,
      activationCoordinate: point.activationCoordinate ?? point.coordinate,
      exposurePaidAt: paidAt ?? DateTime.now(),
      exposureActivationSource: activationSource ?? point.exposureActivationSource,
    );
  }

  /// 이용권으로 추가된 일자리 알림핀(isPremiumSlot) — 노출 활성화 동기화
  static List<PushNotificationBasePoint> syncPaidRecruitmentActivations(
    List<PushNotificationBasePoint> points,
  ) {
    return [
      for (var i = 0; i < points.length; i++)
        PushWalletCreditPolicy.isRecruitmentZoneIndex(i) &&
                points[i].isPremiumSlot &&
                !points[i].exposureActivated
            ? lockActivation(points[i])
            : points[i],
    ];
  }

  /// 저장 시 기존 활성화 상태 유지 + 신규·변경분만 잠금
  static List<PushNotificationBasePoint> mergeActivations({
    required List<PushNotificationBasePoint> before,
    required List<PushNotificationBasePoint> after,
    required bool creditsWereConsumed,
  }) {
    final beforeById = {
      for (var i = 0; i < before.length; i++)
        if (PushWalletCreditPolicy.isRecruitmentZoneIndex(i)) before[i].id: before[i],
    };

    return [
      for (var i = 0; i < after.length; i++)
        _mergePoint(
          index: i,
          point: after[i],
          beforeById: beforeById,
          creditsWereConsumed: creditsWereConsumed,
        ),
    ];
  }

  static PushNotificationBasePoint _mergePoint({
    required int index,
    required PushNotificationBasePoint point,
    required Map<String, PushNotificationBasePoint> beforeById,
    required bool creditsWereConsumed,
  }) {
    if (!PushWalletCreditPolicy.isRecruitmentZoneIndex(index)) {
      return point;
    }

    final prev = beforeById[point.id];
    if (prev == null) {
      return creditsWereConsumed ? lockActivation(point) : point;
    }

    if (!coordinatesMatch(prev.coordinate, point.coordinate)) {
      return creditsWereConsumed ? lockActivation(point) : point;
    }

    if (prev.exposureActivated) {
      return point.copyWith(
        exposureActivated: true,
        activationCoordinate: prev.activationCoordinate ?? prev.coordinate,
        exposurePaidAt: prev.exposurePaidAt,
        exposureActivationSource: prev.exposureActivationSource,
      );
    }

    return point;
  }

  /// PUSH 알림권(단독) 발송 가능 여부 — [null]이면 허용
  static String? pushTicketBlockReason({
    required CorporateJobPost post,
    required PushDispatchTarget target,
    JobPostNotificationSettings? settings,
  }) {
    final resolved = settings ?? post.notificationSettings;

    return switch (target.kind) {
      PushDispatchTargetKind.workplace => null,
      PushDispatchTargetKind.shuttleStop =>
        target.exposureActivated
            ? null
            : '정류장 노출을 먼저 활성화해 주세요. (정류장 표시핀 결제)',
      PushDispatchTargetKind.notificationPin =>
        _recruitmentPinBlockReason(resolved, target),
    };
  }

  static String? _recruitmentPinBlockReason(
    JobPostNotificationSettings? settings,
    PushDispatchTarget target,
  ) {
    if (settings == null || settings.basePoints.isEmpty) {
      return '일자리 알림핀이 설정되지 않았습니다.';
    }

    PushNotificationBasePoint? matched;
    for (var i = 0; i < settings.basePoints.length; i++) {
      if (!PushWalletCreditPolicy.isRecruitmentZoneIndex(i)) continue;
      final p = settings.basePoints[i];
      if (p.id == target.basePointId ||
          'pin_${p.id}' == target.id ||
          target.id.endsWith(p.id)) {
        matched = p;
        break;
      }
    }

    if (matched == null) {
      for (final p in settings.basePoints) {
        if (coordinatesMatch(p.coordinate, target.coordinate)) {
          matched = p;
          break;
        }
      }
    }

    if (matched == null) {
      return '일자리 알림핀을 찾을 수 없습니다.';
    }

    if (!matched.exposureActivated) {
      return '이 위치는 노출 활성화되지 않았습니다. '
          '일자리 알림핀 이용권으로 노출을 활성화한 뒤 PUSH를 보내 주세요.';
    }

    final locked = matched.activationCoordinate ?? matched.coordinate;
    if (!coordinatesMatch(locked, target.coordinate)) {
      return '알림핀 위치가 변경되었습니다. '
          '위치를 바꾸려면 일자리 알림핀 이용권이 필요하며, '
          'PUSH 알림권만으로 여러 장소에 보낼 수 없습니다.';
    }

    return null;
  }

  static bool isPushTicketTargetAllowed({
    required CorporateJobPost post,
    required PushDispatchTarget target,
  }) =>
      pushTicketBlockReason(post: post, target: target) == null;
}
