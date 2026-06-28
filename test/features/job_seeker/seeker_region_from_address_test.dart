import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_region_from_address.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_work_region_matcher.dart';

void main() {
  group('SeekerRegionFromAddress', () {
    test('districtFromRoadAddress maps sigungu from road address', () {
      expect(
        SeekerRegionFromAddress.districtFromRoadAddress(
          '경기도 의정부시 가능로 123',
        ),
        '경기 의정부시',
      );
      expect(
        SeekerRegionFromAddress.districtFromRoadAddress(
          '경기도 용인시 수지구 용구대로 66',
        ),
        '경기 용인시 수지구',
      );
      expect(
        SeekerRegionFromAddress.districtFromRoadAddress(
          '경기 용인시 수지구 용구대로2771번길 66',
        ),
        '경기 용인시 수지구',
      );
      expect(
        SeekerRegionFromAddress.districtFromRoadAddress(
          '서울특별시 강남구 테헤란로 123',
        ),
        '서울 강남구',
      );
      expect(
        SeekerRegionFromAddress.districtFromRoadAddress(
          '서울 강남구 테헤란로 123',
        ),
        '서울 강남구',
      );
    });
  });

  group('SeekerWorkRegionMatcher', () {
    test('overlaps district and legacy sido filter', () {
      expect(
        SeekerWorkRegionMatcher.overlaps('경기 의정부시', '경기'),
        isTrue,
      );
      expect(
        SeekerWorkRegionMatcher.overlaps('경기 의정부시', '경기 평택시'),
        isFalse,
      );
      expect(
        SeekerWorkRegionMatcher.overlaps('경기', '경기 의정부시'),
        isTrue,
      );
    });
  });
}
