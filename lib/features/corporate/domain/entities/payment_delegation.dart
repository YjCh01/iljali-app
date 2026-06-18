import 'package:map/features/corporate/domain/entities/payment_delegation_status.dart';

/// 채용 담당자 → 결제 권한자 위임
class PaymentDelegation {
  const PaymentDelegation({
    required this.recruiterEmail,
    required this.payerEmail,
    required this.status,
    required this.requestedAt,
    required this.requestedByEmail,
    this.acceptedAt,
  });

  final String recruiterEmail;
  final String payerEmail;
  final PaymentDelegationStatus status;
  final DateTime requestedAt;
  final String requestedByEmail;
  final DateTime? acceptedAt;

  bool get isActive => status == PaymentDelegationStatus.accepted;

  String counterpartEmailFor(String myEmail) =>
      myEmail == recruiterEmail ? payerEmail : recruiterEmail;

  PaymentDelegation copyWith({
    PaymentDelegationStatus? status,
    DateTime? acceptedAt,
  }) {
    return PaymentDelegation(
      recruiterEmail: recruiterEmail,
      payerEmail: payerEmail,
      status: status ?? this.status,
      requestedAt: requestedAt,
      requestedByEmail: requestedByEmail,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'recruiterEmail': recruiterEmail,
        'payerEmail': payerEmail,
        'status': status.name,
        'requestedAt': requestedAt.toIso8601String(),
        'requestedByEmail': requestedByEmail,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      };

  factory PaymentDelegation.fromJson(Map<String, dynamic> json) {
    return PaymentDelegation(
      recruiterEmail: json['recruiterEmail'] as String? ?? '',
      payerEmail: json['payerEmail'] as String? ?? '',
      status: parsePaymentDelegationStatus(json['status'] as String?),
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '') ??
          DateTime.now(),
      requestedByEmail: json['requestedByEmail'] as String? ?? '',
      acceptedAt: DateTime.tryParse(json['acceptedAt'] as String? ?? ''),
    );
  }
}
