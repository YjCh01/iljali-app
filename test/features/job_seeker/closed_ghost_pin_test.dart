import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/factories/closed_ghost_job_map_pin_factory.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qualifies expired free post for closed ghost pin', () {
    final postedAt = DateTime.now().subtract(const Duration(days: 3));
    final post = CorporateJobPost(
      id: 'p1',
      title: '마감 공고',
      warehouseName: '강남',
      hourlyWage: '10,000원',
      workSchedule: '09-18',
      summary: '',
      jobDescription: '',
      status: CorporateJobPostStatus.closed,
      applicantCount: 0,
      postedAt: postedAt,
      expiresAt: JobPostValidity.expiresAtFromRegistration(postedAt),
      workerCategory: WorkerCategory.daily,
    );

    expect(ClosedGhostJobMapPinFactory.qualifiesExpiredFreePost(post), isTrue);
  });

  test('paid package post does not qualify for closed ghost pin', () {
    final post = CorporateJobPost(
      id: 'p2',
      title: '유료',
      warehouseName: '강남',
      hourlyWage: '10,000원',
      workSchedule: '09-18',
      summary: '',
      jobDescription: '',
      status: CorporateJobPostStatus.closed,
      applicantCount: 0,
      postedAt: DateTime.now(),
      workerCategory: WorkerCategory.daily,
      mapPinDisplayTier: JobMapPinDisplayTier.packageActive,
    );

    expect(ClosedGhostJobMapPinFactory.qualifiesExpiredFreePost(post), isFalse);
  });

  test('closed ghost pin uses dedicated marker id and message', () {
    final pin = ClosedGhostJobMapPinFactory.fromPost(
      CorporateJobPost(
        id: 'p3',
        title: '마감',
        warehouseName: '역삼',
        hourlyWage: '10,000원',
        workSchedule: '09-18',
        summary: '',
        jobDescription: '',
        status: CorporateJobPostStatus.closed,
        applicantCount: 0,
        postedAt: DateTime.now().subtract(const Duration(days: 2)),
        workerCategory: WorkerCategory.daily,
      ),
      const GeoCoordinate(latitude: 37.5, longitude: 127.0),
    );

    expect(pin.isClosedGhost, isTrue);
    expect(pin.mapMarkerId, 'ghost_post_p3');
    expect(pin.closedGhostMessage, '마감된 공고입니다.');
    expect(pin.displayTier, JobMapPinDisplayTier.closedGhost);
  });
}
