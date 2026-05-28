import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/trust/company_rating.dart';
import 'package:map/core/trust/employer_trust_badge.dart';
import 'package:map/core/trust/employer_trust_service.dart';
import 'package:map/core/trust/local_company_rating_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalCompanyRatingRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('summarizeCompany returns empty when no ratings', () async {
      final repo = await LocalCompanyRatingRepository.create();
      final summary = await repo.summarizeCompany('1234567890');
      expect(summary.reviewCount, 0);
      expect(summary.displayStars, '평가 없음');
    });

    test('save and summarize averages stars', () async {
      final repo = await LocalCompanyRatingRepository.create();
      await repo.save(
        CompanyRating(
          id: 'r1',
          companyKey: '1234567890',
          applicationId: 'app1',
          seekerEmail: 'a@test.com',
          stars: 4,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await repo.save(
        CompanyRating(
          id: 'r2',
          companyKey: '1234567890',
          applicationId: 'app2',
          seekerEmail: 'b@test.com',
          stars: 5,
          createdAt: DateTime(2026, 1, 2),
          tags: const ['급여 약속 준수'],
        ),
      );
      final summary = await repo.summarizeCompany('1234567890');
      expect(summary.reviewCount, 2);
      expect(summary.averageStars, 4.5);
      expect(summary.topTags, contains('급여 약속 준수'));
    });
  });

  group('EmployerTrustService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('assigns premium partner badge for paid subscription', () async {
      const profile = CorporateMemberProfile(
        companyName: '테스트',
        businessRegistrationNumber: '1234567890',
        department: '물류',
        contactPersonName: '홍길동',
        handlerCode: '1001',
        verificationStatus: BusinessVerificationStatus.verified,
        partnershipTier: PremiumPartnershipTier.starter,
        monthlySubscriptionActive: true,
      );

      final summary = await EmployerTrustService().summarize(
        companyKey: profile.companyKey,
        profile: profile,
      );

      expect(
        summary.badges,
        contains(EmployerTrustBadge.premiumPartner),
      );
      expect(
        summary.badges,
        contains(EmployerTrustBadge.verifiedBusiness),
      );
    });
  });
}
