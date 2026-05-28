import 'package:flutter_test/flutter_test.dart';

import 'package:map/core/hiring/insurance_verification_service.dart';

import 'package:map/core/hiring/local_hiring_repository.dart';

import 'package:map/core/hiring/local_permanent_employment_repository.dart';

import 'package:map/core/hiring/monthly_commission.dart';

import 'package:map/core/hiring/permanent_commission_calculator.dart';

import 'package:map/core/hiring/permanent_commission_policy.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:shared_preferences/shared_preferences.dart';



void main() {

  setUp(() {

    SharedPreferences.setMockInitialValues({});

  });



  test('PermanentCommissionCalculator charges 5.5 percent of monthly salary', () {

    expect(PermanentCommissionCalculator.calculateAmount(2500000), 137500);

  });



  test('InsuranceVerificationService validates company name and employment', () {

    final service = InsuranceVerificationService();

    final now = DateTime(2026, 1, 1);



    final ok = service.verify(

      employmentId: 'perm_1',

      employerCompanyName: '(주)일자리',

      workplaceNameFromCertificate: '주식회사 일자리',

      currentlyEmployed: true,

      now: now,

    );

    expect(ok.success, isTrue);



    final fail = service.verify(

      employmentId: 'perm_1',

      employerCompanyName: '(주)일자리',

      workplaceNameFromCertificate: '다른 회사',

      currentlyEmployed: true,

      now: now,

    );

    expect(fail.success, isFalse);

  });



  test('billing cycle creates pending charge after verification', () async {

    final repo = await LocalPermanentEmploymentRepository.create();

    final hireDate = DateTime(2025, 12, 1);



    final employment = await repo.registerHire(

      applicationId: 'app_1',

      companyKey: '1234567890',

      companyName: '(주)일자리',

      seekerEmail: 'worker@example.com',

      seekerName: '김근로',

      monthlySalaryKrw: 2000000,

      hireDate: hireDate,

    );



    final service = InsuranceVerificationService();

    final verification = service.verify(

      employmentId: employment.id,

      employerCompanyName: employment.companyName,

      workplaceNameFromCertificate: employment.companyName,

      currentlyEmployed: true,

      now: hireDate.add(const Duration(days: 3)),

    );

    await repo.saveVerification(verification.log);



    await repo.processDueBillingCycles(

      now: hireDate.add(

        const Duration(days: PermanentCommissionPolicy.billingCycleDays),

      ),

    );



    final commissions = await repo.commissionsForEmployment(employment.id);

    expect(commissions, hasLength(1));

    expect(commissions.first.status, MonthlyCommissionStatus.pending);

    expect(commissions.first.amountKrw, 110000);



    final charged = await repo.markCommissionCharged(commissions.first.id);

    expect(charged.status, MonthlyCommissionStatus.charged);



    await repo.processDueBillingCycles(

      now: hireDate.add(

        const Duration(days: PermanentCommissionPolicy.billingCycleDays * 2),

      ),

    );



    final afterSecond = await repo.commissionsForEmployment(employment.id);

    expect(afterSecond, hasLength(2));

    expect(afterSecond.last.status, MonthlyCommissionStatus.skipped);

  });



  test('submitApplication routes commission by employment type', () async {

    final repo = await LocalHiringRepository.create();



    final daily = await repo.submitApplication(

      postId: 'post_daily',

      postTitle: '일용 모집',

      companyName: '(주)일자리',

      seekerEmail: 'daily@test.com',

      seekerName: '일용',

      seekerPhoneMasked: '010-****',

      workSchedule: '주 5일',

      employmentType: JobEmploymentType.daily,

      hourlyWageText: '12000',

    );

    expect(daily.commissionAmountKrw, isNotNull);



    final permanent = await repo.submitApplication(

      postId: 'post_perm',

      postTitle: '상시 모집',

      companyName: '(주)일자리',

      seekerEmail: 'perm@test.com',

      seekerName: '상시',

      seekerPhoneMasked: '010-****',

      workSchedule: '주 5일',

      employmentType: JobEmploymentType.permanent,

      hourlyWageText: '12000',

    );

    expect(permanent.commissionAmountKrw, isNull);

    expect(permanent.isPermanentEmployment, isTrue);

  });

}


