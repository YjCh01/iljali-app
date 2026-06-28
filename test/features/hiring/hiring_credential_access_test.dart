import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/hiring_credential_access.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_snapshot.dart';

void main() {
  final appliedAt = DateTime(2026, 6, 1);

  group('HiringCredentialAccess', () {
    test('blocks documents before mutual confirmation', () {
      final app = HiringApplication(
        id: 'a1',
        postId: 'p1',
        postTitle: '공고',
        companyName: '기업',
        seekerEmail: 's@test.com',
        seekerName: '홍길동',
        seekerPhoneMasked: '010',
        appliedAt: appliedAt,
        status: HiringApplicationStatus.applied,
        workSchedule: '09-18',
      );
      expect(
        HiringCredentialAccess.canEmployerViewCredentialDocuments(app),
        isFalse,
      );
    });

    test('allows documents after commission paid', () {
      final app = HiringApplication(
        id: 'a1',
        postId: 'p1',
        postTitle: '공고',
        companyName: '기업',
        seekerEmail: 's@test.com',
        seekerName: '홍길동',
        seekerPhoneMasked: '010',
        appliedAt: appliedAt,
        status: HiringApplicationStatus.commissionPaid,
        workSchedule: '09-18',
      );
      expect(
        HiringCredentialAccess.canEmployerViewCredentialDocuments(app),
        isTrue,
      );
    });
  });

  group('SeekerResumeSnapshot credentials', () {
    test('seeker own profile includes document paths', () {
      const profile = SeekerMemberProfile(
        phoneVerified: true,
        credentialHoldings: [
          SeekerCredentialHolding(
            credentialId: 'forklift_operator_cert',
            imagePath: '/tmp/cert.jpg',
          ),
        ],
      );

      final snapshot = SeekerResumeSnapshot.fromProfile(
        name: '홍길동',
        profile: profile,
      );

      expect(snapshot.canViewCredentialDocuments, isTrue);
      expect(snapshot.credentials.single.canViewDocument, isTrue);
      expect(snapshot.credentials.single.imagePath, '/tmp/cert.jpg');
    });

    test('application before hire hides document paths', () {
      final app = HiringApplication(
        id: 'a1',
        postId: 'p1',
        postTitle: '공고',
        companyName: '기업',
        seekerEmail: 'unknown@test.com',
        seekerName: '홍길동',
        seekerPhoneMasked: '010',
        appliedAt: appliedAt,
        status: HiringApplicationStatus.chatting,
        workSchedule: '09-18',
        requiredCredentialIds: const [
          'forklift_operator_cert',
          'construction_safety_basic',
        ],
      );

      final snapshot = SeekerResumeSnapshot.fromApplication(app);

      expect(snapshot.credentialsArePostRequirements, isTrue);
      expect(snapshot.canViewCredentialDocuments, isFalse);
      expect(snapshot.credentials, hasLength(2));
      for (final credential in snapshot.credentials) {
        expect(credential.imagePath, isNull);
      }
    });
  });
}
