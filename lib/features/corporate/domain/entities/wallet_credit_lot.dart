/// 지갑 크레딧 배치(lot) — 언제 지급되고 언제 만료되는지, FIFO 만료 상세 표시용.
class WalletCreditLot {
  const WalletCreditLot({
    required this.creditType,
    required this.remaining,
    required this.grantedAt,
    this.expiresAt,
    this.sourceOrderId,
  });

  final String creditType;
  final int remaining;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final String? sourceOrderId;

  int? get daysUntilExpiry {
    final expires = expiresAt;
    if (expires == null) return null;
    return expires.difference(DateTime.now()).inDays;
  }

  String get creditTypeLabel => switch (creditType) {
        'package' => '일자리 알림핀',
        'push_ticket' => 'PUSH 알림권',
        'exposure_bundle' => '노출+PUSH',
        _ => creditType,
      };

  factory WalletCreditLot.fromJson(Map<String, dynamic> json) {
    return WalletCreditLot(
      creditType: json['credit_type'] as String? ?? '',
      remaining: json['remaining'] as int? ?? 0,
      grantedAt: DateTime.tryParse('${json['granted_at']}Z') ??
          DateTime.now(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse('${json['expires_at']}Z'),
      sourceOrderId: json['source_order_id'] as String?,
    );
  }
}
