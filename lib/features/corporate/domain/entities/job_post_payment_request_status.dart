enum JobPostPaymentRequestStatus {
  pending,
  paid,
  cancelled,
}

extension JobPostPaymentRequestStatusX on JobPostPaymentRequestStatus {
  String get label => switch (this) {
        JobPostPaymentRequestStatus.pending => '결제 대기',
        JobPostPaymentRequestStatus.paid => '결제 완료',
        JobPostPaymentRequestStatus.cancelled => '취소됨',
      };
}

JobPostPaymentRequestStatus parseJobPostPaymentRequestStatus(String? raw) {
  if (raw == null) return JobPostPaymentRequestStatus.pending;
  try {
    return JobPostPaymentRequestStatus.values.byName(raw);
  } on ArgumentError {
    return JobPostPaymentRequestStatus.pending;
  }
}
