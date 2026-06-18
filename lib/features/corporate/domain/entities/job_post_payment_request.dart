import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_status.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// 채용 담당자 → 결제 권한자 공고·유료 서비스 결제 요청
class JobPostPaymentRequest {
  const JobPostPaymentRequest({
    required this.id,
    required this.companyKey,
    required this.requesterEmail,
    required this.payerEmail,
    required this.status,
    required this.jobTitle,
    required this.productLabel,
    required this.amountKrw,
    required this.bundle,
    required this.kind,
    required this.requestedAt,
    this.jobPostId,
    this.paidAt,
    this.transactionId,
    this.requesterDisplayName,
  });

  final String id;
  final String companyKey;
  final String requesterEmail;
  final String? requesterDisplayName;
  final String payerEmail;
  final JobPostPaymentRequestStatus status;
  final String? jobPostId;
  final String jobTitle;
  final String productLabel;
  final int amountKrw;
  final PushPaymentBundle bundle;
  final JobPostPaymentRequestKind kind;
  final DateTime requestedAt;
  final DateTime? paidAt;
  final String? transactionId;

  bool get isPending => status == JobPostPaymentRequestStatus.pending;

  JobPostPaymentRequest copyWith({
    JobPostPaymentRequestStatus? status,
    DateTime? paidAt,
    String? transactionId,
  }) {
    return JobPostPaymentRequest(
      id: id,
      companyKey: companyKey,
      requesterEmail: requesterEmail,
      requesterDisplayName: requesterDisplayName,
      payerEmail: payerEmail,
      status: status ?? this.status,
      jobPostId: jobPostId,
      jobTitle: jobTitle,
      productLabel: productLabel,
      amountKrw: amountKrw,
      bundle: bundle,
      kind: kind,
      requestedAt: requestedAt,
      paidAt: paidAt ?? this.paidAt,
      transactionId: transactionId ?? this.transactionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyKey': companyKey,
        'requesterEmail': requesterEmail,
        if (requesterDisplayName != null)
          'requesterDisplayName': requesterDisplayName,
        'payerEmail': payerEmail,
        'status': status.name,
        'jobPostId': jobPostId,
        'jobTitle': jobTitle,
        'productLabel': productLabel,
        'amountKrw': amountKrw,
        'bundle': bundle.toJson(),
        'kind': kind.name,
        'requestedAt': requestedAt.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'transactionId': transactionId,
      };

  factory JobPostPaymentRequest.fromJson(Map<String, dynamic> json) {
    return JobPostPaymentRequest(
      id: json['id'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      requesterEmail: json['requesterEmail'] as String? ?? '',
      requesterDisplayName: json['requesterDisplayName'] as String?,
      payerEmail: json['payerEmail'] as String? ?? '',
      status: parseJobPostPaymentRequestStatus(json['status'] as String?),
      jobPostId: json['jobPostId'] as String?,
      jobTitle: json['jobTitle'] as String? ?? '공고',
      productLabel: json['productLabel'] as String? ?? '',
      amountKrw: json['amountKrw'] as int? ?? 0,
      bundle: PushPaymentBundle.fromJson(
        (json['bundle'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      kind: parseJobPostPaymentRequestKind(json['kind'] as String?),
      requestedAt:
          DateTime.tryParse(json['requestedAt'] as String? ?? '') ??
              DateTime.now(),
      paidAt: DateTime.tryParse(json['paidAt'] as String? ?? ''),
      transactionId: json['transactionId'] as String?,
    );
  }
}
