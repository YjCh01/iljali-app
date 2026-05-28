/// 기업회원 홈 대시보드 mock 데이터
class CorporateDashboardSummary {
  const CorporateDashboardSummary({
    required this.activeJobPosts,
    required this.newApplicantsToday,
    required this.todayAttendanceRate,
    required this.unreadChats,
    required this.recentApplicants,
    required this.activeJobs,
  });

  final int activeJobPosts;
  final int newApplicantsToday;
  final int todayAttendanceRate;
  final int unreadChats;
  final List<CorporateApplicantPreview> recentApplicants;
  final List<CorporateJobPreview> activeJobs;
}

class CorporateApplicantPreview {
  const CorporateApplicantPreview({
    required this.name,
    required this.jobTitle,
    required this.appliedAtLabel,
  });

  final String name;
  final String jobTitle;
  final String appliedAtLabel;
}

class CorporateJobPreview {
  const CorporateJobPreview({
    required this.title,
    required this.applicantCount,
    required this.statusLabel,
  });

  final String title;
  final int applicantCount;
  final String statusLabel;
}

abstract class CorporateDashboardLocalDataSource {
  Future<CorporateDashboardSummary> fetchSummary();
}

class CorporateDashboardLocalDataSourceImpl
    implements CorporateDashboardLocalDataSource {
  const CorporateDashboardLocalDataSourceImpl();

  @override
  Future<CorporateDashboardSummary> fetchSummary() async {
    return const CorporateDashboardSummary(
      activeJobPosts: 0,
      newApplicantsToday: 0,
      todayAttendanceRate: 0,
      unreadChats: 0,
      recentApplicants: [],
      activeJobs: [],
    );
  }
}
