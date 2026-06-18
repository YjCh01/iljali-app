import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';

void main() {
  setUp(() {
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
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

  test('blocks post save when workplace mismatches head office', () async {
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
      summary: '요약',
      jobDescription: '상세',
      paymentSchedule: SalaryPaymentAbsoluteDate(DateTime(2026, 6, 1)),
      workerCategory: WorkerCategory.daily,
      registeredBy: profile,
    );

    expect(result.isSuccess, isFalse);
    expect(
      AuthSession.instance.currentUser?.corporateProfile?.requiresAdminReview,
      isTrue,
    );
  });
}
