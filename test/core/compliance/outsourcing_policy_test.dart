import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/contact_entitlement.dart';
import 'package:map/core/compliance/outsourcing_policy.dart';
import 'package:map/core/compliance/services/contact_entitlement_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

void main() {
  group('OutsourcingPolicy', () {
    test('flags outsourcing-related industries', () {
      expect(OutsourcingPolicy.industryRequiresAdminReview('인력공급업'), isTrue);
      expect(OutsourcingPolicy.industryRequiresAdminReview('물류대행'), isFalse);
    });
  });

  group('ContactEntitlementService', () {
    final service = ContactEntitlementService();

    test('allows admin review pending profile', () {
      const profile = CorporateMemberProfile(
        companyName: '테스트',
        businessRegistrationNumber: '1234567890',
        department: '인사',
        contactPersonName: '홍길동',
        handlerCode: '1001',
        requiresAdminReview: true,
        adminReviewApproved: false,
        verificationStatus: BusinessVerificationStatus.adminReviewRequired,
      );

      final result = service.evaluate(profile);
      expect(result, ContactAccessResult.allowedFull);
    });

    test('allows BASIC profile for contact', () {
      const profile = CorporateMemberProfile(
        companyName: '테스트',
        businessRegistrationNumber: '1234567890',
        department: '인사',
        contactPersonName: '홍길동',
        handlerCode: '1001',
        partnershipTier: PremiumPartnershipTier.basic,
        monthlySubscriptionActive: false,
        verificationStatus: BusinessVerificationStatus.verified,
      );

      final result = service.evaluate(profile);
      expect(result, ContactAccessResult.allowedFull);
    });

    test('allows full access for legacy paid subscription', () {
      const profile = CorporateMemberProfile(
        companyName: '테스트',
        businessRegistrationNumber: '1234567890',
        department: '인사',
        contactPersonName: '홍길동',
        handlerCode: '1001',
        partnershipTier: PremiumPartnershipTier.starter,
        monthlySubscriptionActive: true,
        verificationStatus: BusinessVerificationStatus.verified,
      );

      final result = service.evaluate(profile);
      expect(result, ContactAccessResult.allowedFull);
    });
  });
}
