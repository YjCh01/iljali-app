import 'package:flutter_test/flutter_test.dart';

import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';



void main() {

  group('CorporateMemberProfile.isEnterpriseOutsourcing', () {

    test('flag alone enables outsourcing edition', () {

      const profile = CorporateMemberProfile(

        companyName: 'Test',

        businessRegistrationNumber: '123-45-67890',

        department: 'HR',

        contactPersonName: 'Kim',

        handlerCode: '1001',

        isEnterpriseOutsourcingEdition: true,

      );

      expect(profile.isEnterpriseOutsourcing, isTrue);

    });



    test('legacy enterprise tier alone does not enable outsourcing', () {

      const profile = CorporateMemberProfile(

        companyName: 'Test',

        businessRegistrationNumber: '123-45-67890',

        department: 'HR',

        contactPersonName: 'Kim',

        handlerCode: '1001',

        partnershipTier: PremiumPartnershipTier.enterprise,

        requiresAdminReview: true,

        adminReviewApproved: true,

      );

      expect(profile.isEnterpriseOutsourcing, isFalse);

    });



    test('enterprise without admin approval is not outsourcing edition', () {

      const profile = CorporateMemberProfile(

        companyName: 'Test',

        businessRegistrationNumber: '123-45-67890',

        department: 'HR',

        contactPersonName: 'Kim',

        handlerCode: '1001',

        partnershipTier: PremiumPartnershipTier.enterprise,

        requiresAdminReview: true,

        adminReviewApproved: false,

      );

      expect(profile.isEnterpriseOutsourcing, isFalse);

    });

  });

}


