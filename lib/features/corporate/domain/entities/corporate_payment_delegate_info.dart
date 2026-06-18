/// 채용 담당자(A) 기준 결제 위임·담당자 정보
class CorporatePaymentDelegateInfo {
  const CorporatePaymentDelegateInfo({
    required this.isPaymentAuthority,
    required this.canRequestPayment,
    this.payerEmail,
    this.payerDisplayName,
    this.hasAcceptedDelegation = false,
  });

  final bool isPaymentAuthority;
  final bool canRequestPayment;
  final String? payerEmail;
  final String? payerDisplayName;
  final bool hasAcceptedDelegation;

  String get payerShortLabel {
    final name = payerDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = payerEmail?.trim();
    if (email != null && email.isNotEmpty) {
      final local = email.split('@').first;
      return local.isNotEmpty ? local : email;
    }
    return '결제 담당자';
  }

  String get delegateBannerTitle => hasAcceptedDelegation
      ? '결제 담당: $payerShortLabel님 · 직접 결제도 가능'
      : '결제는 $payerShortLabel님(결제 권한자)에게 요청합니다';

  String exposureActionLabel(String product) => isPaymentAuthority
      ? '$product 결제'
      : '$payerShortLabel님에게 $product 결제 요청';

  String directPayLabel(String product) => '$product 결제';

  /// 위임 완료 + 비결제권한자 — 요청과 직접 결제 둘 다 가능
  bool get showDualPaymentActions =>
      canRequestPayment && hasAcceptedDelegation && !isPaymentAuthority;

  String get batchRequestButtonLabel =>
      '$payerShortLabel님에게 결제 요청 보내기';
}
