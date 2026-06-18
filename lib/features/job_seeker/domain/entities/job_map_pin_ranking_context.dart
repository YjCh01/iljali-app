/// 클러스터 목록 정렬 — 구직자 맞춤 입력 (MVP: 위치만)
class JobMapPinRankingContext {
  const JobMapPinRankingContext({
    this.seekerLatitude,
    this.seekerLongitude,
    this.preferShuttle = false,
  });

  final double? seekerLatitude;
  final double? seekerLongitude;

  /// 「셔틀 있음」 필터·정렬 시 셔틀 공고 우대
  final bool preferShuttle;

  bool get hasSeekerLocation =>
      seekerLatitude != null && seekerLongitude != null;
}
