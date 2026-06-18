enum JobPostPaymentRequestKind {
  jobPinExposure,
  shuttleStopExposure,
  pushTicket,
  packagePurchase,
  extraPush,
}

extension JobPostPaymentRequestKindX on JobPostPaymentRequestKind {
  String get label => switch (this) {
        JobPostPaymentRequestKind.jobPinExposure => '일자리 알림핀 노출',
        JobPostPaymentRequestKind.shuttleStopExposure => '정류장 표시핀 노출',
        JobPostPaymentRequestKind.pushTicket => 'PUSH 이용권',
        JobPostPaymentRequestKind.packagePurchase => '알림핀 패키지',
        JobPostPaymentRequestKind.extraPush => '추가 PUSH',
      };
}

JobPostPaymentRequestKind parseJobPostPaymentRequestKind(String? raw) {
  if (raw == null) return JobPostPaymentRequestKind.jobPinExposure;
  try {
    return JobPostPaymentRequestKind.values.byName(raw);
  } on ArgumentError {
    return JobPostPaymentRequestKind.jobPinExposure;
  }
}
