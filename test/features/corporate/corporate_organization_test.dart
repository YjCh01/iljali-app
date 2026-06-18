import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/data/repositories/corporate_organization_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_org_role.dart';
import 'package:map/features/corporate/domain/services/commission_payer_resolver.dart';
import 'package:map/features/corporate/domain/services/corporate_org_join_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const companyKey = '1234567890';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CorporateOrganizationRepository> orgRepo() =>
      CorporateOrganizationRepository.create();

  test('joinMember adds recruiters under same BRN', () async {
    final repo = await orgRepo();
    await repo.joinMember(
      companyKey: companyKey,
      email: 'recruiter-a@corp.test',
      name: '담당A',
      handlerCode: '1001',
    );
    await repo.joinMember(
      companyKey: companyKey,
      email: 'recruiter-b@corp.test',
      name: '담당B',
      handlerCode: '1002',
    );

    final members = await repo.listMembers(companyKey);
    expect(members.length, 2);
    expect(members.first.email, 'recruiter-a@corp.test');
    expect(await repo.isFounder(companyKey: companyKey, email: 'recruiter-a@corp.test'), isTrue);
  });

  test('founder assigns payment authority and delegation routes payer', () async {
    final repo = await orgRepo();
    await repo.joinMember(
      companyKey: companyKey,
      email: 'founder@corp.test',
      name: '대표',
    );
    await repo.joinMember(
      companyKey: companyKey,
      email: 'payer@corp.test',
      name: '결제자',
    );
    await repo.joinMember(
      companyKey: companyKey,
      email: 'recruiter@corp.test',
      name: '채용',
    );

    final assigned = await repo.assignPaymentAuthorityRole(
      companyKey: companyKey,
      actorEmail: 'founder@corp.test',
      targetEmail: 'payer@corp.test',
    );
    expect(assigned, isTrue);

    final payerMember = await repo.findMember(
      companyKey: companyKey,
      email: 'payer@corp.test',
    );
    expect(payerMember?.role, CorporateOrgRole.paymentAuthority);

    await repo.requestDelegation(
      companyKey: companyKey,
      recruiterEmail: 'recruiter@corp.test',
      payerEmail: 'payer@corp.test',
      requestedByEmail: 'recruiter@corp.test',
    );
    final accepted = await repo.respondDelegation(
      companyKey: companyKey,
      recruiterEmail: 'recruiter@corp.test',
      payerEmail: 'payer@corp.test',
      responderEmail: 'payer@corp.test',
      accept: true,
    );
    expect(accepted?.status.name, 'accepted');

    final resolver = CommissionPayerResolver(repo);
    final payer = await resolver.resolvePayerEmail(
      companyKey: companyKey,
      recruiterEmail: 'recruiter@corp.test',
    );
    expect(payer, 'payer@corp.test');
  });

  test('without delegation payer falls back to recruiter', () async {
    final repo = await orgRepo();
    await repo.joinMember(
      companyKey: companyKey,
      email: 'solo@corp.test',
      name: '단독',
    );

    final resolver = CommissionPayerResolver(repo);
    final payer = await resolver.resolvePayerEmail(
      companyKey: companyKey,
      recruiterEmail: 'solo@corp.test',
    );
    expect(payer, 'solo@corp.test');
  });

  test('fetchPendingCommissionsForPayer filters by delegation', () async {
    final repo = await orgRepo();
    await repo.joinMember(
      companyKey: companyKey,
      email: 'founder@corp.test',
      name: '대표',
    );
    await repo.joinMember(
      companyKey: companyKey,
      email: 'payer@corp.test',
      name: '결제',
    );
    await repo.joinMember(
      companyKey: companyKey,
      email: 'recruiter@corp.test',
      name: '채용',
    );
    await repo.assignPaymentAuthorityRole(
      companyKey: companyKey,
      actorEmail: 'founder@corp.test',
      targetEmail: 'payer@corp.test',
    );
    await repo.requestDelegation(
      companyKey: companyKey,
      recruiterEmail: 'recruiter@corp.test',
      payerEmail: 'payer@corp.test',
      requestedByEmail: 'recruiter@corp.test',
    );
    await repo.respondDelegation(
      companyKey: companyKey,
      recruiterEmail: 'recruiter@corp.test',
      payerEmail: 'payer@corp.test',
      responderEmail: 'payer@corp.test',
      accept: true,
    );

    final hiringRepo = await LocalHiringRepository.create();
    final app = await hiringRepo.submitApplication(
      postId: 'post_delegation',
      postTitle: '위임 테스트',
      companyName: '테스트',
      seekerEmail: 'seeker@test.com',
      seekerName: '구직',
      seekerPhoneMasked: '010',
      workSchedule: '09-18',
      companyKey: companyKey,
      recruiterEmail: 'recruiter@corp.test',
    );
    final scheduled = await hiringRepo.instantAccept(
      applicationId: app.id,
      workDate: DateTime(2020, 1, 1),
    );
    await hiringRepo.checkIn(scheduled.id);
    await hiringRepo.confirmEmployerAttendance(scheduled.id);

    final payerPending =
        await hiringRepo.fetchPendingCommissionsForPayer('payer@corp.test');
    expect(payerPending.length, 1);

    final recruiterPending =
        await hiringRepo.fetchPendingCommissionsForPayer('recruiter@corp.test');
    expect(recruiterPending, isEmpty);
  });

  test('CorporateOrgJoinService syncProfile upserts member', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: companyKey,
      department: '인사',
      contactPersonName: '홍길동',
      handlerCode: '1001',
    );
    await const CorporateOrgJoinService().syncProfile(
      email: 'sync@corp.test',
      name: '홍길동',
      profile: profile,
      phone: '01012345678',
    );
    final repo = await orgRepo();
    final member = await repo.findMember(
      companyKey: companyKey,
      email: 'sync@corp.test',
    );
    expect(member, isNotNull);
    expect(member!.department, '인사');
    expect(member.phone, '01012345678');
  });
}
