/// 결제 화면 진입 시 직접 결제 vs 담당자 요청
enum CorporatePaymentPreference {
  /// 권한·위임 상태에 따라 자동 (기본: 직접 결제 우선)
  auto,

  /// 본인 카드로 즉시 결제
  direct,

  /// 결제 권한자에게 요청
  request,
}
