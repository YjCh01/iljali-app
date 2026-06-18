import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';

/// 기업 관점 — 구직자의 우리 회사 지원·출근 이력
abstract final class CorporateApplicantHistory {
  static List<HiringApplication> seekerApplicationsAtCompany({
    required List<HiringApplication> companyApplications,
    required String seekerEmail,
  }) {
    final normalized = seekerEmail.trim().toLowerCase();
    return companyApplications
        .where((app) => app.seekerEmail.trim().toLowerCase() == normalized)
        .toList()
      ..sort((a, b) => a.appliedAt.compareTo(b.appliedAt));
  }

  /// 이 기업 공고에서 실제 출근(확인·정산) 완료 횟수
  static int companyCheckInCount({
    required List<HiringApplication> companyApplications,
    required String seekerEmail,
  }) {
    return seekerApplicationsAtCompany(
      companyApplications: companyApplications,
      seekerEmail: seekerEmail,
    ).where(_isCompletedCheckIn).length;
  }

  /// 이 기업에 몇 번째 지원인지 (1차, 2차, …)
  static int applicationAttempt({
    required List<HiringApplication> companyApplications,
    required String seekerEmail,
    required String applicationId,
  }) {
    final history = seekerApplicationsAtCompany(
      companyApplications: companyApplications,
      seekerEmail: seekerEmail,
    );
    final index = history.indexWhere((app) => app.id == applicationId);
    return index >= 0 ? index + 1 : 1;
  }

  static bool _isCompletedCheckIn(HiringApplication app) =>
      app.status == HiringApplicationStatus.checkedIn ||
      app.status == HiringApplicationStatus.commissionPaid;
}
