import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_merge.dart';

void main() {
  test('mergePreferRicher unions credential holdings from all sources', () {
    final server = SeekerMemberProfile(
      phoneVerified: true,
      onboardingCompletedAt: DateTime(2026, 1, 1),
      credentialHoldings: const [],
    );
    final local = SeekerMemberProfile(
      phoneVerified: true,
      credentialHoldings: const [
        SeekerCredentialHolding(
          credentialId: 'health_certificate',
          imagePath: '/local/health.jpg',
        ),
      ],
    );

    final merged = SeekerProfileMerge.mergePreferRicher([server, local]);
    expect(merged.credentialHoldings.length, 1);
    expect(merged.credentialHoldings.first.credentialId, 'health_certificate');
    expect(merged.credentialHoldings.first.hasPhoto, isTrue);
  });
}
