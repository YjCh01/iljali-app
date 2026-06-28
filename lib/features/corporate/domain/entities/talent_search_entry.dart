/// 인재 검색 결과 카드 (이름·연락처 비공개 요약)
class TalentSearchEntry {
  const TalentSearchEntry({
    required this.seekerEmail,
    required this.displayNameMasked,
    required this.credentialIds,
    required this.credentialLabels,
    required this.preferredRegions,
    required this.availableWeekdays,
    required this.experienceCount,
    required this.proposalOffersAccepted,
  });

  final String seekerEmail;
  final String displayNameMasked;
  final List<String> credentialIds;
  final List<String> credentialLabels;
  final List<String> preferredRegions;
  final List<int> availableWeekdays;
  final int experienceCount;
  final bool proposalOffersAccepted;

  String get weekdaySummary {
    if (availableWeekdays.isEmpty) return '요일 미등록';
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    final sorted = [...availableWeekdays]..sort();
    return sorted.map((d) => labels[d.clamp(0, 6)]).join('·');
  }

  String get regionSummary =>
      preferredRegions.isEmpty ? '지역 미등록' : preferredRegions.take(3).join(' · ');
}
