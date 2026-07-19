/// 연도별 최저시급 — 고용노동부 고시 기준.
abstract final class MinimumWageTable {
  static const Map<int, int> _hourlyByYear = {
    2023: 9620,
    2024: 9860,
    2025: 10030,
    2026: 10320,
  };

  static int hourlyWage(int year) {
    if (_hourlyByYear.containsKey(year)) return _hourlyByYear[year]!;
    final years = _hourlyByYear.keys.toList()..sort();
    if (year < years.first) return _hourlyByYear[years.first]!;
    return _hourlyByYear[years.last]!;
  }

  static int get latestYear => (_hourlyByYear.keys.toList()..sort()).last;
}
