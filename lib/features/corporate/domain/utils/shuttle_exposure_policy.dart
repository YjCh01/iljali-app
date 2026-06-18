import 'package:map/features/corporate/domain/utils/job_post_validity.dart';

/// 정류장 표시핀 노출 기간 (D+1 23:59:59)
abstract final class ShuttleExposurePolicy {
  static DateTime expiresAtFromPayment(DateTime paidAt) =>
      JobPostValidity.expiresAtFromRegistration(paidAt);

  static bool isActive(DateTime? paidAt, [DateTime? now]) {
    if (paidAt == null) return false;
    return !JobPostValidity.isExpired(expiresAtFromPayment(paidAt), now);
  }

  static String remainingLabel(DateTime expiresAt, [DateTime? now]) {
    final clock = now ?? DateTime.now();
    if (clock.isAfter(expiresAt)) return '노출 종료';
    final diff = expiresAt.difference(clock);
    if (diff.inDays >= 1) {
      return '${diff.inDays}일 ${diff.inHours % 24}시간 남음';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}시간 ${diff.inMinutes % 60}분 남음';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}분 남음';
    }
    return '곧 종료';
  }
}
