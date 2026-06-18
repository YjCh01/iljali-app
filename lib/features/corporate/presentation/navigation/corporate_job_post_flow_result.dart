/// 공고 등록 플로우 종료 — 기업 셸 탭 전환
class CorporateJobPostFlowResult {
  const CorporateJobPostFlowResult({this.shellTabIndex = 1});

  /// [CorporateHomeShellPage] 하단 탭 (0=홈, 1=공고, …)
  final int shellTabIndex;
}
