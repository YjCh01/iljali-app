import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  group('MapPinTierResolver', () {
    test('100-pack buyer gets premium pin', () {
      const profile = CorporateMemberProfile(
        companyName: 'A',
        businessRegistrationNumber: '123',
        department: 'HR',
        contactPersonName: 'Kim',
        handlerCode: '0001',
        pushWallet: EmployerPushWallet(purchased100PackBundle: true),
      );
      final tier = MapPinTierResolver.resolveForNewPost(
        registeredBy: profile,
      );
      expect(tier, JobMapPinDisplayTier.premiumPartner);
    });

    test('default profile gets grey standard pin', () {
      const profile = CorporateMemberProfile(
        companyName: 'A',
        businessRegistrationNumber: '123',
        department: 'HR',
        contactPersonName: 'Kim',
        handlerCode: '0001',
      );
      final tier = MapPinTierResolver.resolveForNewPost(
        registeredBy: profile,
      );
      expect(tier, JobMapPinDisplayTier.standard);
    });

    test('stored tier on post is respected', () {
      final post = CorporateJobPost(
        id: 'p1',
        title: 't',
        warehouseName: 'w',
        hourlyWage: '1',
        workSchedule: 's',
        summary: 'x',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 5, 1),
        mapPinDisplayTier: JobMapPinDisplayTier.premiumPartner,
      );
      expect(
        MapPinTierResolver.resolve(post: post),
        JobMapPinDisplayTier.premiumPartner,
      );
    });
  });
}
