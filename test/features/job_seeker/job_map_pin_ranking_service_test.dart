import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_ranking_context.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_pin_ranking_service.dart';

JobMapPin _pin({
  required String id,
  JobMapPinDisplayTier tier = JobMapPinDisplayTier.standard,
  int applicants = 0,
  DateTime? postedAt,
  DateTime? expiresAt,
  bool verified = false,
  double lat = 37.5,
  double lng = 127.03,
}) {
  return JobMapPin(
    post: CorporateJobPost(
      id: id,
      title: '공고 $id',
      warehouseName: '센터',
      hourlyWage: '12,000원',
      workSchedule: '주5',
      summary: '요약',
      jobDescription: '상세',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: applicants,
      postedAt: postedAt ?? DateTime(2026, 5, 20),
      expiresAt: expiresAt,
      registeredBy: verified
          ? const CorporateMemberProfile(
              companyName: '검증사',
              businessRegistrationNumber: '123',
              department: '인사',
              contactPersonName: '담당',
              handlerCode: '1001',
              verificationStatus: BusinessVerificationStatus.verified,
            )
          : null,
      mapPinDisplayTier: tier,
    ),
    latitude: lat,
    longitude: lng,
    companyName: '회사',
    displayTier: tier,
  );
}

void main() {
  final now = DateTime(2026, 5, 27, 12);

  test('premium alone does not beat high-performing fresh standard pin', () {
    final ranked = JobMapPinRankingService.rankClusterPins(
      [
        _pin(
          id: 'paid-old',
          tier: JobMapPinDisplayTier.premiumPartner,
          applicants: 0,
          postedAt: now.subtract(const Duration(days: 5)),
        ),
        _pin(
          id: 'hot',
          tier: JobMapPinDisplayTier.standard,
          applicants: 18,
          postedAt: now.subtract(const Duration(hours: 6)),
          verified: true,
        ),
      ],
      now: now,
    );

    expect(ranked.first.post.id, 'hot');
  });

  test('recency and applicants rank above stale low-activity pin', () {
    final ranked = JobMapPinRankingService.rankClusterPins(
      [
        _pin(
          id: 'stale',
          postedAt: now.subtract(const Duration(days: 10)),
          applicants: 1,
        ),
        _pin(
          id: 'fresh',
          postedAt: now.subtract(const Duration(hours: 2)),
          applicants: 8,
        ),
      ],
      now: now,
    );

    expect(ranked.first.post.id, 'fresh');
  });

  test('seeker location boosts nearer pin when other signals similar', () {
    const context = JobMapPinRankingContext(
      seekerLatitude: 37.5,
      seekerLongitude: 127.03,
    );
    final ranked = JobMapPinRankingService.rankClusterPins(
      [
        _pin(id: 'far', lat: 37.52, lng: 127.06, applicants: 5),
        _pin(id: 'near', lat: 37.501, lng: 127.031, applicants: 5),
      ],
      context: context,
      now: now,
    );

    expect(ranked.first.post.id, 'near');
  });

  test('JobMapCluster.rankedPins uses same ordering', () {
    final cluster = JobMapCluster(
      pins: [
        _pin(id: 'a', applicants: 0),
        _pin(id: 'b', applicants: 15, postedAt: now.subtract(const Duration(hours: 1))),
      ],
      latitude: 37.5,
      longitude: 127.03,
      displayTier: JobMapPinDisplayTier.standard,
    );

    expect(cluster.rankedPins(now: now).first.post.id, 'b');
  });
}
