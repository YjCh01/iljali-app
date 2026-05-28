/// ROI 대시보드 집계 기간
enum RoiPeriod {
  days30(30, '최근 30일'),
  days90(90, '최근 90일'),
  all(null, '전체');

  const RoiPeriod(this.days, this.label);

  final int? days;
  final String label;

  DateTime? sinceFrom(DateTime now) {
    if (days == null) return null;
    return now.subtract(Duration(days: days!));
  }
}
