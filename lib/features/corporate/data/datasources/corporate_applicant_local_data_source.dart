import 'package:map/core/session/auth_session.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';

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
    return applications.map(_mapApplication).toList();
  }

  CorporateApplicant _mapApplication(HiringApplication app) {
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
      seekerEmail: app.seekerEmail,
      jobPostId: app.postId,
    );
  }

  CorporateApplicantStatus _mapStatus(HiringApplicationStatus status) =>
      switch (status) {
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
      };
}
