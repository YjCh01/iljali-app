import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_readiness.dart';

void main() {
  group('SeekerProfileReadiness', () {
    test('isMatchingReady accepts filled profile without onboarding flag', () {
      const profile = SeekerMemberProfile(
        phoneVerified: true,
        residentIdFront7: '900101-1',
        preferredRegions: ['경기 의정부시'],
        workAvailability: SeekerWorkAvailability(
          slots: [
            SeekerAvailabilitySlot(weekday: 0, anyTime: true),
          ],
        ),
        homeRoadAddress: '경기 의정부시 가능동 1',
      );

      expect(
        SeekerProfileReadiness.isMatchingReady(
          profile,
          displayName: '홍길동',
        ),
        isTrue,
      );
    });

    test('missingMatchingFields lists incomplete items', () {
      const profile = SeekerMemberProfile(phoneVerified: true);

      expect(
        SeekerProfileReadiness.missingMatchingFields(
          profile,
          displayName: '',
        ),
        containsAll(['이름', '주민번호 앞자리', '실주소', '희망 근무지역', '근무 스케줄']),
      );
    });

    test('onboarding flag alone still passes', () {
      final profile = SeekerMemberProfile(
        phoneVerified: true,
        onboardingCompletedAt: DateTime(2026, 1, 1),
      );

      expect(
        SeekerProfileReadiness.isMatchingReady(profile, displayName: ''),
        isTrue,
      );
    });
  });
}
