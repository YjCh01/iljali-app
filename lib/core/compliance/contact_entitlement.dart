/// 연락·채팅 접근 판정 결과
class ContactAccessResult {
  const ContactAccessResult({
    required this.allowed,
    this.blockReason,
    this.showPartnershipUpsell = false,
    this.remainingMonthlyContacts,
    this.requiresPerContactPayment = false,
    this.perContactFeeKrw,
  });

  final bool allowed;
  final String? blockReason;
  final bool showPartnershipUpsell;
  final int? remainingMonthlyContacts;
  final bool requiresPerContactPayment;
  final int? perContactFeeKrw;

  static const allowedFull = ContactAccessResult(allowed: true);

  static ContactAccessResult blocked({
    required String reason,
    bool upsell = false,
    int? remaining,
    int? perContactFee,
  }) =>
      ContactAccessResult(
        allowed: false,
        blockReason: reason,
        showPartnershipUpsell: upsell,
        remainingMonthlyContacts: remaining,
        requiresPerContactPayment: perContactFee != null,
        perContactFeeKrw: perContactFee,
      );
}
