/// 희망 지역 ↔ 필터 지역 매칭 (시·도-only 레거시 포함)
abstract final class SeekerWorkRegionMatcher {
  static bool overlaps(String seekerRegion, String filterRegion) {
    final seeker = seekerRegion.trim();
    final filter = filterRegion.trim();
    if (seeker.isEmpty || filter.isEmpty) return false;
    if (seeker == filter) return true;
    if (seeker.startsWith('$filter ')) return true;
    if (filter.startsWith('$seeker ')) return true;
    return false;
  }

  static bool anyOverlap(
    Iterable<String> seekerRegions,
    Iterable<String> filterRegions,
  ) {
    for (final filter in filterRegions) {
      for (final seeker in seekerRegions) {
        if (overlaps(seeker, filter)) return true;
      }
    }
    return false;
  }
}
