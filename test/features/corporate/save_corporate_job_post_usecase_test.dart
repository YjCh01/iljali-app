import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/services/unverified_employer_trial_post_policy.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('reactivates expired job post with new exposure period', () async {
    const dataSource = CorporateJobPostLocalDataSourceImpl();
    final expiredAt = DateTime(2020, 1, 1, 23, 59, 59);
    final expired = CorporateJobPost(
      id: 'post_expired',
      title: '만료 공고',
      warehouseName: '서울 강남구',
      hourlyWage: '12,000원',
      workSchedule: '주5일 09:00~18:00',
      summary: '요약',
      status: CorporateJobPostStatus.closed,
      applicantCount: 2,
      postedAt: DateTime(2019, 12, 31),
      expiresAt: expiredAt,
    );
    await dataSource.createJobPost(expired);

    final useCase = ReactivateCorporateJobPostUseCase(dataSource);
    final before = DateTime.now();
    final result = await useCase(expired);
    final after = DateTime.now();

    expect(result.isSuccess, isTrue);
    final reactivated = result.post!;
    expect(reactivated.status, CorporateJobPostStatus.recruiting);
    expect(reactivated.isExpired, isFalse);
    expect(
      reactivated.postedAt.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      reactivated.postedAt.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      reactivated.expiresAt,
      JobPostValidity.expiresAtFromRegistration(reactivated.postedAt),
    );

    final stored = await dataSource.findById('post_expired');
    expect(stored?.postedAt, reactivated.postedAt);
    expect(stored?.expiresAt, reactivated.expiresAt);
    expect(stored?.status, CorporateJobPostStatus.recruiting);
  });

  test('allows post save when workplace mismatches head office', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1231231231',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '9999',
      businessHeadOfficeAddress: '서울 강남구 테헤란로 1',
    );
    await AuthSession.instance.signIn(
      AuthUser(
        name: '담당자',
        email: 'corp@example.com',
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );

    final useCase = CreateCorporateJobPostUseCase(
      const CorporateJobPostLocalDataSourceImpl(),
    );
    final result = await useCase.call(
      title: '창고 피킹',
      workplace: const WorkplaceAddress(roadAddress: '서울 마포구 월드컵북로 1'),
      hourlyWage: '12000',
      workSchedule: '주5일 09:00~18:00',
      descriptionBody: const JobPostDescriptionBody(text: '상세'),
      paymentSchedule: SalaryPaymentAbsoluteDate(DateTime(2026, 6, 1)),
      workerCategory: WorkerCategory.daily,
      registeredBy: profile,
    );

    expect(result.isSuccess, isTrue);
    expect(result.post?.warehouseName, contains('마포구'));
    expect(
      AuthSession.instance.currentUser?.corporateProfile?.requiresAdminReview,
      isFalse,
    );
  });

  test('unverified employer gets exactly one free 24-hour job post', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트미인증',
      businessRegistrationNumber: '2222222222',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1111',
    );

    final useCase = CreateCorporateJobPostUseCase(
      const CorporateJobPostLocalDataSourceImpl(),
    );
    final first = await useCase.call(
      title: '1차 공고',
      workplace: const WorkplaceAddress(roadAddress: '서울 마포구 월드컵북로 1'),
      hourlyWage: '12000',
      workSchedule: '주5일 09:00~18:00',
      descriptionBody: const JobPostDescriptionBody(text: '상세'),
      paymentSchedule: SalaryPaymentAbsoluteDate(DateTime(2026, 6, 1)),
      workerCategory: WorkerCategory.daily,
      registeredBy: profile,
    );

    expect(first.isSuccess, isTrue);
    expect(
      first.post?.expiresAt,
      UnverifiedEmployerTrialPostPolicy.trialExpiresAt(first.post!.postedAt),
    );

    final second = await useCase.call(
      title: '2차 공고',
      workplace: const WorkplaceAddress(roadAddress: '서울 마포구 월드컵북로 2'),
      hourlyWage: '12000',
      workSchedule: '주5일 09:00~18:00',
      descriptionBody: const JobPostDescriptionBody(text: '상세'),
      paymentSchedule: SalaryPaymentAbsoluteDate(DateTime(2026, 6, 1)),
      workerCategory: WorkerCategory.daily,
      registeredBy: profile,
    );

    expect(second.isSuccess, isFalse);
    expect(second.message, contains('1회'));
  });

  test('verified employer is never limited by the trial policy', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트인증',
      businessRegistrationNumber: '3333333333',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '2222',
      verificationStatus: BusinessVerificationStatus.verified,
    );

    final useCase = CreateCorporateJobPostUseCase(
      const CorporateJobPostLocalDataSourceImpl(),
    );
    for (var i = 0; i < 2; i++) {
      final result = await useCase.call(
        title: '공고 $i',
        workplace: const WorkplaceAddress(roadAddress: '서울 마포구 월드컵북로 1'),
        hourlyWage: '12000',
        workSchedule: '주5일 09:00~18:00',
        descriptionBody: const JobPostDescriptionBody(text: '상세'),
        paymentSchedule: SalaryPaymentAbsoluteDate(DateTime(2026, 6, 1)),
        workerCategory: WorkerCategory.daily,
        registeredBy: profile,
      );
      expect(result.isSuccess, isTrue);
      expect(
        result.post?.expiresAt,
        JobPostValidity.expiresAtFromRegistration(result.post!.postedAt),
      );
    }
  });

  test('blocks reactivation for unverified employer who already used trial',
      () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트미인증2',
      businessRegistrationNumber: '4444444444',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '3333',
    );
    await UnverifiedEmployerTrialPostPolicy.markTrialPostUsed(
      profile.companyKey,
    );

    const dataSource = CorporateJobPostLocalDataSourceImpl();
    final expired = CorporateJobPost(
      id: 'post_expired_unverified',
      title: '만료 공고',
      warehouseName: '서울 강남구',
      hourlyWage: '12,000원',
      workSchedule: '주5일 09:00~18:00',
      summary: '요약',
      status: CorporateJobPostStatus.closed,
      applicantCount: 0,
      postedAt: DateTime(2019, 12, 31),
      expiresAt: DateTime(2020, 1, 1, 23, 59, 59),
      registeredBy: profile,
    );
    await dataSource.createJobPost(expired);

    final useCase = ReactivateCorporateJobPostUseCase(dataSource);
    final result = await useCase(expired);

    expect(result.isSuccess, isFalse);
  });
}
