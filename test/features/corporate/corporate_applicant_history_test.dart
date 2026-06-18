import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/features/corporate/domain/utils/corporate_applicant_history.dart';

HiringApplication _app({
  required String id,
  required String seekerEmail,
  required DateTime appliedAt,
  HiringApplicationStatus status = HiringApplicationStatus.applied,
}) {
  return HiringApplication(
    id: id,
    postId: 'post-1',
    postTitle: '물류 보조',
    companyName: '테스트기업',
    seekerEmail: seekerEmail,
    seekerName: '구직자',
    seekerPhoneMasked: '010-****-0000',
    appliedAt: appliedAt,
    status: status,
    workSchedule: '주 5일',
    companyKey: 'corp-alpha',
  );
}

void main() {
  test('companyCheckInCount counts only completed check-ins at company', () {
    final apps = [
      _app(
        id: 'a1',
        seekerEmail: 'beta@test.com',
        appliedAt: DateTime(2026, 5, 1),
        status: HiringApplicationStatus.commissionPaid,
      ),
      _app(
        id: 'a2',
        seekerEmail: 'beta@test.com',
        appliedAt: DateTime(2026, 5, 10),
        status: HiringApplicationStatus.chatting,
      ),
      _app(
        id: 'a3',
        seekerEmail: 'other@test.com',
        appliedAt: DateTime(2026, 5, 2),
        status: HiringApplicationStatus.checkedIn,
      ),
    ];

    expect(
      CorporateApplicantHistory.companyCheckInCount(
        companyApplications: apps,
        seekerEmail: 'beta@test.com',
      ),
      1,
    );
  });

  test('applicationAttempt orders by appliedAt within company', () {
    final apps = [
      _app(
        id: 'old',
        seekerEmail: 'beta@test.com',
        appliedAt: DateTime(2026, 4, 1),
        status: HiringApplicationStatus.rejected,
      ),
      _app(
        id: 'mid',
        seekerEmail: 'beta@test.com',
        appliedAt: DateTime(2026, 5, 1),
        status: HiringApplicationStatus.commissionPaid,
      ),
      _app(
        id: 'new',
        seekerEmail: 'beta@test.com',
        appliedAt: DateTime(2026, 5, 30),
        status: HiringApplicationStatus.chatting,
      ),
    ];

    expect(
      CorporateApplicantHistory.applicationAttempt(
        companyApplications: apps,
        seekerEmail: 'beta@test.com',
        applicationId: 'new',
      ),
      3,
    );
    expect(
      CorporateApplicantHistory.applicationAttempt(
        companyApplications: apps,
        seekerEmail: 'beta@test.com',
        applicationId: 'old',
      ),
      1,
    );
  });
}
