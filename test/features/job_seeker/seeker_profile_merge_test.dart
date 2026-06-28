import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_merge.dart';

void main() {
  group('SeekerProfileMerge', () {
    test('prefers local rich profile over empty server profile', () {
      const local = SeekerMemberProfile(
        phoneVerified: true,
        residentIdFront7: '900101-1',
        homeRoadAddress: '경기 용인시 수지구',
        preferredRegions: ['경기 용인시'],
        workAvailability: SeekerWorkAvailability(
          slots: [SeekerAvailabilitySlot(weekday: 0, anyTime: true)],
        ),
        onboardingCompletedAt: null,
      );
      const server = SeekerMemberProfile(phoneVerified: true);

      final merged = SeekerProfileMerge.mergePreferRicher(
        [server, local],
        displayName: '최영진',
      );

      expect(merged.homeRoadAddress, local.homeRoadAddress);
      expect(merged.preferredRegions, local.preferredRegions);
      expect(merged.residentIdFront7, local.residentIdFront7);
    });
  });
}
