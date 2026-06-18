import 'package:map/core/compliance/data/compliance_repository.dart';

class CollusionReportSubmission {
  const CollusionReportSubmission({
    required this.applicationId,
    required this.companyKey,
    required this.reason,
    this.detail,
    this.rewardRegionCreditStub = 1,
  });

  final String applicationId;
  final String companyKey;
  final String reason;
  final String? detail;

  /// 향후 "희망 근무지역 크레딧" 지급 연동용 스텁 값
  final int rewardRegionCreditStub;
}

/// 구직자 담합/오프플랫폼 유도 신고 스텁
class CollusionReportService {
  Future<void> submit(CollusionReportSubmission report) async {
    final repo = await ComplianceRepository.create();
    await repo.addAbuseFlag({
      'type': 'collusion_report',
      'severity': 'high',
      'companyKey': report.companyKey,
      'applicationId': report.applicationId,
      'message': report.reason,
      'detail': report.detail,
      'rewardRegionCreditStub': report.rewardRegionCreditStub,
    });
  }
}
