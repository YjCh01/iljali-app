import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/job_seeker/presentation/map/job_recruitment_map_pin.dart';

void main() {
  PushNotificationBasePoint point({
    required String id,
    required double lat,
    required double lng,
    bool locked = false,
    String? colorHex,
  }) {
    return PushNotificationBasePoint(
      id: id,
      coordinate: GeoCoordinate(latitude: lat, longitude: lng),
      addressLabel: id,
      exposureActivated: locked,
      exposurePaidAt: locked ? DateTime.now() : null,
      pinColorHex: colorHex,
    );
  }

  CorporateJobPost postWithPins(List<PushNotificationBasePoint> points) {
    return CorporateJobPost(
      id: 'job1',
      title: 'test1',
      warehouseName: '아라',
      hourlyWage: '시급 10,000원',
      workSchedule: '월-금',
      summary: 's',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: DateTime(2026, 7, 1),
      workplaceLatitude: 37.0,
      workplaceLongitude: 127.0,
      notificationSettings: JobPostNotificationSettings(basePoints: points),
    );
  }

  test('notification settings JSON round-trip keeps alert pins + color', () {
    final settings = JobPostNotificationSettings(
      basePoints: [
        point(id: 'wp', lat: 37.0, lng: 127.0),
        point(id: 'a1', lat: 37.01, lng: 127.01, locked: true, colorHex: '#E74C3C'),
        point(id: 'a2', lat: 37.02, lng: 127.02, locked: true, colorHex: '#2ECC71'),
        point(id: 'a3', lat: 37.03, lng: 127.03, locked: true, colorHex: '#3498DB'),
      ],
    );

    final restored = JobPostNotificationSettings.tryParseJsonString(
      settings.toJsonString(),
    );
    expect(restored, isNotNull);
    expect(restored!.basePoints, hasLength(4));
    expect(restored.basePoints[3].pinColorHex, '#3498DB');
    expect(restored.basePoints[1].isExposureLocked, isTrue);
  });

  test('factory returns locked alert pins only by default', () {
    final post = postWithPins([
      point(id: 'wp', lat: 37.0, lng: 127.0),
      point(id: 'a1', lat: 37.01, lng: 127.01, locked: true),
      point(id: 'a2', lat: 37.02, lng: 127.02),
    ]);
    final pins = JobRecruitmentMapPinFactory.fromPost(post);
    expect(pins, hasLength(1));
    expect(pins.first.index, 1);
  });

  test('own posts can show configured unlocked alert pins', () {
    final post = postWithPins([
      point(id: 'wp', lat: 37.0, lng: 127.0),
      point(id: 'a1', lat: 37.01, lng: 127.01),
      point(id: 'a2', lat: 37.02, lng: 127.02),
      point(id: 'a3', lat: 37.03, lng: 127.03, colorHex: '#ABCDEF'),
    ]);
    final pins = JobRecruitmentMapPinFactory.fromPosts(
      [post],
      ownPostIdsAlwaysShowConfigured: {'job1'},
    );
    expect(pins, hasLength(3));
    expect(pins.last.point.pinColorHex, '#ABCDEF');
  });
}
