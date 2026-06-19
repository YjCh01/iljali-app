import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/utils/corporate_map_content_access_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

CorporateJobPost _post({String? ownerBrn}) {
  return CorporateJobPost(
    id: 'p1',
    title: '테스트',
    warehouseName: 'w',
    hourlyWage: '12,000원',
    workSchedule: '주5',
    summary: '요약',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 0,
    postedAt: DateTime(2026, 6, 1),
    registeredBy: ownerBrn == null
        ? null
        : CorporateMemberProfile(
            companyName: 'B',
            businessRegistrationNumber: ownerBrn,
            department: 'HR',
            contactPersonName: 'Lee',
            handlerCode: '2001',
          ),
  );
}

void main() {
  group('CorporateMapContentAccessPolicy', () {
    const viewer = CorporateMemberProfile(
      companyName: 'A',
      businessRegistrationNumber: '111-22-33333',
      department: 'HR',
      contactPersonName: 'Kim',
      handlerCode: '1001',
    );

    test('free employer cannot view competitor posts', () {
      expect(
        CorporateMapContentAccessPolicy.hasPaidIntelAccess(viewer),
        isFalse,
      );
      expect(
        CorporateMapContentAccessPolicy.canViewPostContent(
          viewerProfile: viewer,
          ownPostIds: const {},
          post: _post(ownerBrn: '999-88-77777'),
        ),
        isFalse,
      );
    });

    test('paid wallet unlocks competitor posts', () {
      const paidViewer = CorporateMemberProfile(
        companyName: 'A',
        businessRegistrationNumber: '1112233333',
        department: 'HR',
        contactPersonName: 'Kim',
        handlerCode: '1001',
        pushWallet: EmployerPushWallet(packageCredits: 1),
      );
      expect(
        CorporateMapContentAccessPolicy.canViewPostContent(
          viewerProfile: paidViewer,
          ownPostIds: const {},
          post: _post(ownerBrn: '9998877777'),
        ),
        isTrue,
      );
    });

    test('free employer can always view own posts', () {
      final ownPost = _post(ownerBrn: '1112233333');
      expect(
        CorporateMapContentAccessPolicy.canViewPostContent(
          viewerProfile: viewer,
          ownPostIds: {ownPost.id},
          post: ownPost,
        ),
        isTrue,
      );
    });

    test('legacy subscription unlocks intel access', () {
      const legacy = CorporateMemberProfile(
        companyName: 'A',
        businessRegistrationNumber: '1112233333',
        department: 'HR',
        contactPersonName: 'Kim',
        handlerCode: '1001',
        partnershipTier: PremiumPartnershipTier.starter,
        monthlySubscriptionActive: true,
      );
      expect(
        CorporateMapContentAccessPolicy.hasPaidIntelAccess(legacy),
        isTrue,
      );
    });

    test('free employer cannot view competitor shuttle routes', () {
      const viewer = CorporateMemberProfile(
        companyName: 'A',
        businessRegistrationNumber: '1112233333',
        department: 'HR',
        contactPersonName: 'Kim',
        handlerCode: '1001',
      );
      expect(
        CorporateMapContentAccessPolicy.canViewShuttleContent(
          viewerProfile: viewer,
          routeCompanyKey: '9998877777',
        ),
        isFalse,
      );
    });

    test('own company shuttle routes remain viewable when free', () {
      const viewer = CorporateMemberProfile(
        companyName: 'A',
        businessRegistrationNumber: '1112233333',
        department: 'HR',
        contactPersonName: 'Kim',
        handlerCode: '1001',
      );
      expect(
        CorporateMapContentAccessPolicy.canViewShuttleContent(
          viewerProfile: viewer,
          routeCompanyKey: '1112233333',
        ),
        isTrue,
      );
    });
  });
}
