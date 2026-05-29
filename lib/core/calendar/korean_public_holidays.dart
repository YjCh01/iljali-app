/// 대한민국 공휴일 (양력 고정 + 주요 연휴일 yyyy-MM-dd)
abstract final class KoreanPublicHolidays {
  static const _fixedMonthDay = <String>{
    '01-01', // 신정
    '03-01', // 삼일절
    '05-05', // 어린이날
    '06-06', // 현충일
    '08-15', // 광복절
    '10-03', // 개천절
    '10-09', // 한글날
    '12-25', // 크리스마스
  };

  /// 설·추석·대체공휴일 등 연도별 지정 (2025~2027)
  static const _variableDates = <String>{
    // 2025
    '2025-01-28', '2025-01-29', '2025-01-30', // 설
    '2025-05-05', // 어린이날·부처님오신날
    '2025-06-03', // 대통령선거 임시공휴일 (2025)
    '2025-10-05', '2025-10-06', '2025-10-07', '2025-10-08', // 추석
    // 2026
    '2026-02-16', '2026-02-17', '2026-02-18', // 설
    '2026-05-05',
    '2026-05-24', // 부처님오신날
    '2026-09-24', '2026-09-25', '2026-09-26', '2026-09-27', // 추석
    // 2027
    '2027-02-06', '2027-02-07', '2027-02-08', // 설
    '2027-05-05',
    '2027-05-13', // 부처님오신날
    '2027-09-14', '2027-09-15', '2027-09-16', '2027-09-17', // 추석
  };

  static bool isHoliday(DateTime date) {
    final md =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_fixedMonthDay.contains(md)) return true;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _variableDates.contains(key);
  }
}
