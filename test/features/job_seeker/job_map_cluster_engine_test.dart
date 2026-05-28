import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_cluster_engine.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

CorporateJobPost _mockPost(String id) => CorporateJobPost(
      id: id,
      title: 'test',
      warehouseName: 'test',
      hourlyWage: '10000원',
      workSchedule: '주5',
      summary: 'summary',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: DateTime(2026, 5, 1),
    );

JobMapPin _pin(String id, double lat, double lng) => JobMapPin(
      post: _mockPost(id),
      latitude: lat,
      longitude: lng,
      companyName: 'company',
      displayTier: JobMapPinDisplayTier.standard,
    );

void main() {
  test('JobMapClusterEngine merges at low zoom and splits at high zoom', () {
    final pins = [
      _pin('1', 37.50, 127.03),
      _pin('2', 37.501, 127.031),
      _pin('3', 37.54, 127.05),
    ];

    final merged = JobMapClusterEngine.cluster(pins: pins, zoom: 10);
    final split = JobMapClusterEngine.cluster(pins: pins, zoom: 16);

    expect(merged.length, lessThanOrEqualTo(split.length));
    expect(merged.any((cluster) => cluster.count > 1), isTrue);
    expect(split.any((cluster) => cluster.isSingle), isTrue);
  });
}
