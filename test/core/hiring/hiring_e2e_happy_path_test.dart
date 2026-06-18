import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/features/corporate/data/datasources/corporate_attendance_local_data_source.dart';
import 'package:map/features/corporate/data/datasources/corporate_chat_local_data_source.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// corp-alpha → 공고 등록 → 지도 핀 → seeker-alpha 지원 → 채팅 →
/// 근무합의 → 출근·쌍방확인 → 수수료 에스컬레이션 → 결제 완료
void main() {
  const jobPosts = CorporateJobPostLocalDataSourceImpl();
  const workplace = WorkplaceAddress(
    roadAddress: '경기도 화성시 동탄대로 123',
    dongName: '동탄',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
  });

  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  test('full hiring happy path with dev test accounts', () async {
    const corp = DevTestAccounts.corpAlpha;
    const seeker = DevTestAccounts.seekerAlpha;
    final profile = corp.verifiedCorporateProfile!;

    // ── 1. 기업 로그인 + 공고 업로드 ──
    await AuthSession.instance.signIn(corp.toAuthUser());
    expect(AuthSession.instance.currentUser?.email, corp.email);

    final createPost = const CreateCorporateJobPostUseCase(jobPosts);
    final postResult = await createPost.call(
      title: '[E2E] 물류 보조 테스트',
      workplace: workplace,
      hourlyWage: '12000',
      workSchedule: '09:00-18:00',
      summary: 'E2E 통합 테스트용 공고',
      jobDescription: '피킹·포장 보조',
      paymentSchedule: SalaryPaymentAbsoluteDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
      workerCategory: WorkerCategory.daily,
      registeredBy: profile,
    );
    expect(postResult.isSuccess, isTrue, reason: postResult.message);
    final post = postResult.post!;
    expect(post.status, CorporateJobPostStatus.recruiting);
    expect(post.isActiveForSeekers, isTrue);

    // ── 2–3. 지도 핀 노출 + 구직자 조회 ──
    final pins = await const GetJobMapPinsUseCase(
      JobMapPinsLocalDataSource(jobPosts: jobPosts),
    ).call();
    expect(
      pins.any((pin) => pin.post.id == post.id),
      isTrue,
      reason: 'active post should appear on map pins',
    );
    final pin = pins.firstWhere((p) => p.post.id == post.id);

    // ── 4. 목록/상세 (repository-level: post lookup) ──
    final detail = await jobPosts.findById(post.id);
    expect(detail?.title, post.title);
    expect(detail?.hourlyWage, contains('12'));

    // ── 5. 구직자 지원 ──
    await AuthSession.instance.signIn(seeker.toAuthUser());
    final hiringRepo = await LocalHiringRepository.create();
    final application = await hiringRepo.submitApplication(
      postId: pin.post.id,
      postTitle: pin.post.title,
      companyName: pin.companyName,
      companyKey: profile.companyKey,
      seekerEmail: seeker.email,
      seekerName: seeker.displayName,
      seekerPhoneMasked: '010-****-0001',
      workSchedule: pin.post.workSchedule,
      suggestedWorkDate: pin.post.paymentDate,
      hourlyWageText: pin.post.hourlyWage,
      employmentType: pin.post.employmentType,
      workplaceLatitude: pin.latitude,
      workplaceLongitude: pin.longitude,
    );
    expect(application.status, HiringApplicationStatus.applied);
    expect(
      await hiringRepo.hasApplied(post.id, seeker.email),
      isTrue,
    );

    // ── 6. 채팅 시작 + 접근 정책 ──
    final chatPolicy = ChatAccessPolicy.evaluatePair(
      requester: MemberType.individual,
      peer: MemberType.corporate,
    );
    expect(chatPolicy.allowed, isTrue);

    await hiringRepo.startChat(application.id);
    var chatting = await hiringRepo.findById(application.id);
    expect(chatting?.status, HiringApplicationStatus.chatting);

    await AuthSession.instance.signIn(corp.toAuthUser());
    final corpChatRooms =
        await const CorporateChatLocalDataSourceImpl().fetchChatRooms();
    expect(
      corpChatRooms.any((room) => room.id == application.id),
      isTrue,
    );

    // ── 7. 근무예정 쌍방 합의 ──
    await AuthSession.instance.signIn(seeker.toAuthUser());
    var agreed = await hiringRepo.confirmWorkScheduleAgreement(
      applicationId: application.id,
      asEmployer: false,
    );
    expect(agreed.seekerWorkAgreedAt, isNotNull);
    expect(agreed.isWorkAgreementComplete, isFalse);

    await AuthSession.instance.signIn(corp.toAuthUser());
    agreed = await hiringRepo.confirmWorkScheduleAgreement(
      applicationId: application.id,
      asEmployer: true,
    );
    expect(agreed.isWorkAgreementComplete, isTrue);
    expect(agreed.status, HiringApplicationStatus.scheduled);
    expect(agreed.workDate, isNotNull);

    final attendanceBefore =
        await const CorporateAttendanceLocalDataSourceImpl().fetchRecords();
    expect(
      attendanceBefore.any((r) => r.applicationId == application.id),
      isTrue,
    );

    // ── 8–9. 출근 + 기업 확인 → 쌍방 근무 확인 ──
    await AuthSession.instance.signIn(seeker.toAuthUser());
    var checkedIn = await hiringRepo.checkIn(
      application.id,
      latitude: pin.latitude,
      longitude: pin.longitude,
    );
    expect(checkedIn.seekerCheckedIn, isTrue);
    expect(checkedIn.isMutuallyConfirmed, isFalse);

    await AuthSession.instance.signIn(corp.toAuthUser());
    final mutual = await hiringRepo.confirmEmployerAttendance(application.id);
    expect(mutual.isMutuallyConfirmed, isTrue);
    expect(mutual.status, HiringApplicationStatus.checkedIn);
    expect(mutual.needsCommissionPayment, isTrue);
    expect(
      mutual.commissionAmountKrw,
      CommissionCalculator.dailyWorkerFee(),
    );

    final pending = await hiringRepo.fetchPendingCommissions();
    expect(pending.any((p) => p.id == application.id), isTrue);

    // ── 10. 수수료 정산 알림 (에스컬레이션) + 결제 ──
    final overdueSeed = mutual.copyWith(
      commissionDueAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    SharedPreferences.setMockInitialValues({
      'hiring_applications_v1': jsonEncode([overdueSeed.toJson()]),
    });
    final overdueRepo = await LocalHiringRepository.create();
    final escalated = await overdueRepo.escalateOverdueCommissions();
    expect(escalated, hasLength(1));
    expect(escalated.first.escalationLevel, 1);

    final paid = await overdueRepo.markCommissionPaid(application.id);
    expect(paid.status, HiringApplicationStatus.commissionPaid);
    expect(paid.commissionPaidAt, isNotNull);
    expect(paid.needsCommissionPayment, isFalse);

    final afterChat =
        await const CorporateChatLocalDataSourceImpl().fetchChatRooms();
    expect(
      afterChat.any((room) => room.id == application.id),
      isFalse,
      reason: 'commissionPaid applications hidden from chat list',
    );
  });
}
