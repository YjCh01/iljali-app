import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/constants/labor_constants.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  group('MapPinTierResolver', () {
    test('100-pack buyer gets standard pin without active credits', () {
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
      expect(tier, JobMapPinDisplayTier.standard);
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

    test('stored tier on post is respected and combined with wage tier', () {
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
        mapPinDisplayTier: JobMapPinDisplayTier.packageActive,
      );
      expect(
        MapPinTierResolver.resolve(post: post),
        JobMapPinDisplayTier.packageActive,
      );
    });

    test('hourly wage at threshold gets premiumWage tier', () {
      final post = CorporateJobPost(
        id: 'p2',
        title: 't',
        warehouseName: 'w',
        hourlyWage:
            '시급 ${LaborConstants.premiumHourlyThreshold}원',
        workSchedule: 's',
        summary: 'x',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 5, 1),
      );
      expect(
        MapPinTierResolver.resolveWageTier(
          hourlyWage: post.hourlyWage,
          workSchedule: post.workSchedule,
        ),
        JobMapPinDisplayTier.premiumWage,
      );
    });

    test('hourly wage below threshold stays standard', () {
      final post = CorporateJobPost(
        id: 'p3',
        title: 't',
        warehouseName: 'w',
        hourlyWage: '시급 10,000원',
        workSchedule: 's',
        summary: 'x',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 5, 1),
      );
      expect(
        MapPinTierResolver.resolve(post: post),
        JobMapPinDisplayTier.standard,
      );
    });

    test('daily wage above threshold with 8h schedule gets premiumWage tier', () {
      final post = CorporateJobPost(
        id: 'p4',
        title: 't',
        warehouseName: 'w',
        hourlyWage: '일급 150,000원',
        workSchedule: '09:00~18:00',
        summary: 'x',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 5, 1),
      );
      expect(
        MapPinTierResolver.resolve(post: post),
        JobMapPinDisplayTier.premiumWage,
      );
    });

    test('daily wage below threshold stays standard', () {
      final post = CorporateJobPost(
        id: 'p4b',
        title: 't',
        warehouseName: 'w',
        hourlyWage: '일급 80,000원',
        workSchedule: '09:00~18:00',
        summary: 'x',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 5, 1),
      );
      expect(
        MapPinTierResolver.resolveWageTier(
          hourlyWage: post.hourlyWage,
          workSchedule: post.workSchedule,
        ),
        JobMapPinDisplayTier.standard,
      );
    });

    test('resolveForNewPost includes wage tier when saving', () {
      final tier = MapPinTierResolver.resolveForNewPost(
        registeredBy: null,
        hourlyWage: '시급 12,000원',
      );
      expect(tier, JobMapPinDisplayTier.premiumWage);
    });

    test('premiumWage sort order is between standard and packageActive', () {
      expect(
        JobMapPinDisplayTier.premiumWage.sortOrder,
        greaterThan(JobMapPinDisplayTier.standard.sortOrder),
      );
      expect(
        JobMapPinDisplayTier.premiumWage.sortOrder,
        lessThan(JobMapPinDisplayTier.packageActive.sortOrder),
      );
    });
  });
}
