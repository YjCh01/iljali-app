/// 공고 노출 기간 — 등록 시점부터 익일 23:59:59
abstract final class JobPostValidity {
  static DateTime expiresAtFromRegistration(DateTime registeredAt) {
    final dayAfter = DateTime(
      registeredAt.year,
      registeredAt.month,
      registeredAt.day,
    ).add(const Duration(days: 1));
    return DateTime(
      dayAfter.year,
      dayAfter.month,
      dayAfter.day,
      23,
      59,
      59,
    );
  }

  static bool isExpired(DateTime expiresAt, [DateTime? now]) {
    return (now ?? DateTime.now()).isAfter(expiresAt);
  }
}
