import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/corporate_verification_access_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

void main() {
  group('CorporateVerificationAccessPolicy', () {
    const provisional = CorporateMemberProfile(
      companyName: '신규물류',
      businessRegistrationNumber: '5555555555',
      department: '인사',
      contactPersonName: '김담당',
      handlerCode: '1001',
      verificationStatus: BusinessVerificationStatus.pending,
    );

    const verified = CorporateMemberProfile(
      companyName: '검증완료',
      businessRegistrationNumber: '1234567891',
      department: '인사',
      contactPersonName: '홍길동',
      handlerCode: '1001',
      verificationStatus: BusinessVerificationStatus.verified,
    );

    const awaitingReview = CorporateMemberProfile(
      companyName: '등록증제출',
      businessRegistrationNumber: '1234567891',
      department: '인사',
      contactPersonName: '홍길동',
      handlerCode: '1001',
      verificationStatus: BusinessVerificationStatus.adminReviewRequired,
      requiresAdminReview: true,
    );

    test('provisional member can post free jobs but not paid', () {
      expect(CorporateVerificationAccessPolicy.canPostFreeJobs(provisional), isTrue);
      expect(CorporateVerificationAccessPolicy.canUsePaidServices(provisional), isFalse);
      expect(
        CorporateVerificationAccessPolicy.paidServicesBlockedReason(provisional),
        contains('미인증'),
      );
    });

    test('verified member can use paid services', () {
      expect(CorporateVerificationAccessPolicy.canUsePaidServices(verified), isTrue);
    });

    test('certificate review pending blocks paid until approved', () {
      expect(CorporateVerificationAccessPolicy.canPostFreeJobs(awaitingReview), isTrue);
      expect(CorporateVerificationAccessPolicy.canUsePaidServices(awaitingReview), isFalse);
      expect(
        CorporateVerificationAccessPolicy.paidServicesBlockedReason(awaitingReview),
        contains('검토'),
      );
    });

    test('approved admin review unlocks paid', () {
      const approved = CorporateMemberProfile(
        companyName: '승인완료',
        businessRegistrationNumber: '1234567891',
        department: '인사',
        contactPersonName: '홍길동',
        handlerCode: '1001',
        verificationStatus: BusinessVerificationStatus.verified,
        requiresAdminReview: true,
        adminReviewApproved: true,
      );
      expect(CorporateVerificationAccessPolicy.canUsePaidServices(approved), isTrue);
    });
  });
}
