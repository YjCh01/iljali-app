/// 결제 권한 위임 상태
enum PaymentDelegationStatus {
  pending,
  accepted,
  rejected,
}

extension PaymentDelegationStatusX on PaymentDelegationStatus {
  String get label => switch (this) {
        PaymentDelegationStatus.pending => '승인 대기',
        PaymentDelegationStatus.accepted => '위임 완료',
        PaymentDelegationStatus.rejected => '거절됨',
      };
}

PaymentDelegationStatus parsePaymentDelegationStatus(String? raw) {
  if (raw == null) return PaymentDelegationStatus.pending;
  try {
    return PaymentDelegationStatus.values.byName(raw);
  } on ArgumentError {
    return PaymentDelegationStatus.pending;
  }
}
