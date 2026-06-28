import 'package:map/core/session/auth_session.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';
import 'package:map/features/corporate/domain/utils/corporate_applicant_history.dart';

abstract class CorporateApplicantLocalDataSource {
  Future<List<CorporateApplicant>> fetchApplicants();
}

class CorporateApplicantLocalDataSourceImpl
    implements CorporateApplicantLocalDataSource {
  const CorporateApplicantLocalDataSourceImpl();

  @override
  Future<List<CorporateApplicant>> fetchApplicants() async {
    final repo = await LocalHiringRepository.create();
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    final applications =
        await repo.fetchApplicantsForCorporate(companyKey: companyKey);
    final allCompanyApps = companyKey == null || companyKey.isEmpty
        ? applications
        : (await repo.fetchAll())
            .where((item) => item.companyKey == companyKey)
            .toList();
    return applications
        .map((app) => _mapApplication(app, allCompanyApps))
        .toList();
  }

  CorporateApplicant _mapApplication(
    HiringApplication app,
    List<HiringApplication> allCompanyApps,
  ) {
    final seekerEmail = app.seekerEmail;
    return CorporateApplicant(
      id: app.id,
      applicationId: app.id,
      name: app.seekerName,
      jobTitle: app.postTitle,
      phoneMasked: app.seekerPhoneMasked,
      status: _mapStatus(app.status),
      appliedAtLabel: LocalHiringRepository.formatRelativeTime(app.appliedAt),
      workDateLabel: app.workDate != null
          ? LocalHiringRepository.formatWorkDateFull(app.workDate!)
          : null,
      seekerEmail: seekerEmail,
      jobPostId: app.postId,
      companyCheckInCount: CorporateApplicantHistory.companyCheckInCount(
        companyApplications: allCompanyApps,
        seekerEmail: seekerEmail,
      ),
      applicationAttempt: CorporateApplicantHistory.applicationAttempt(
        companyApplications: allCompanyApps,
        seekerEmail: seekerEmail,
        applicationId: app.id,
      ),
    );
  }

  CorporateApplicantStatus _mapStatus(HiringApplicationStatus status) =>
      switch (status) {
        HiringApplicationStatus.inquiry =>
          CorporateApplicantStatus.chatting,
        HiringApplicationStatus.applied => CorporateApplicantStatus.pending,
        HiringApplicationStatus.chatting =>
          CorporateApplicantStatus.chatting,
        HiringApplicationStatus.scheduled =>
          CorporateApplicantStatus.scheduled,
        HiringApplicationStatus.checkedIn =>
          CorporateApplicantStatus.checkedIn,
        HiringApplicationStatus.commissionPaid =>
          CorporateApplicantStatus.commissionPaid,
        HiringApplicationStatus.rejected => CorporateApplicantStatus.rejected,
        HiringApplicationStatus.noShow => CorporateApplicantStatus.rejected,
      };
}
