import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/job_post_workplace_resolver.dart';

void main() {
  test('geocodeQueryCandidates strips trailing detail numbers', () {
    const address = '경기 안성시 대덕면 소동산길 3-29 1234';
    final queries = JobPostWorkplaceResolver.geocodeQueryCandidates(address);

    expect(queries, contains('경기 안성시 대덕면 소동산길 3-29'));
  });

  test('geocodeQueryCandidates strips parenthetical building labels', () {
    const address =
        '경기 안성시 소동산길 3-29 (무능리) 다이소 안성물류센터';
    final queries = JobPostWorkplaceResolver.geocodeQueryCandidates(address);

    expect(queries.first, address);
    expect(queries, contains('경기 안성시 소동산길 3-29'));
    expect(
      queries.where((q) => !q.contains('(')).any((q) => q.contains('소동산길')),
      isTrue,
    );
  });

  test('resolveMapWorkplaceCoordinate uses notification base point 0', () {
    const anseong = GeoCoordinate(latitude: 37.005, longitude: 127.234);
    final post = CorporateJobPost(
      id: 'post-1',
      title: '테스트',
      warehouseName: '경기 안성시 소동산길 3-29',
      hourlyWage: '10,000원',
      workSchedule: '09-18',
      summary: '',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: DateTime(2026, 6, 1),
      notificationSettings: JobPostNotificationSettings(
        basePoints: [
          const PushNotificationBasePoint(
            id: 'workplace',
            coordinate: anseong,
            addressLabel: '근무지',
          ),
        ],
      ),
    );

    final resolved = JobPostWorkplaceResolver.resolveMapWorkplaceCoordinate(post);

    expect(resolved.latitude, closeTo(anseong.latitude, 0.001));
    expect(resolved.longitude, closeTo(anseong.longitude, 0.001));
  });
}
