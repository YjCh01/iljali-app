import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_snapshot.dart';

HiringApplication _application({
  required HiringApplicationStatus status,
  List<String> requiredCredentialIds = const [],
}) {
  return HiringApplication(
    id: 'app_1',
    postId: 'post_1',
    postTitle: '물류센터 상하차',
    companyName: '테스트기업',
    seekerEmail: 'unknown-seeker@test.iljari.co.kr',
    seekerName: '구직자',
    seekerPhoneMasked: '010-****-1234',
    appliedAt: DateTime(2026, 1, 1),
    status: status,
    workSchedule: '09:00-18:00',
    requiredCredentialIds: requiredCredentialIds,
  );
}

void main() {
  group('SeekerResumeSnapshot.fromApplication with serverCredentialHoldings', () {
    test('marks a credential held via has_photo even when imagePath is redacted', () {
      final snapshot = SeekerResumeSnapshot.fromApplication(
        _application(
          status: HiringApplicationStatus.applied,
          requiredCredentialIds: ['forklift_operator_cert'],
        ),
        serverCredentialHoldings: const [
          {'credentialId': 'forklift_operator_cert', 'has_photo': true},
        ],
        serverCanViewDocuments: false,
      );

      expect(snapshot.credentials, hasLength(1));
      final credential = snapshot.credentials.single;
      expect(credential.isHeld, isTrue);
      expect(credential.imagePath, isNull);
      expect(credential.canViewDocument, isFalse);
    });

    test('reveals imagePath once server says documents are viewable', () {
      final snapshot = SeekerResumeSnapshot.fromApplication(
        _application(
          status: HiringApplicationStatus.scheduled,
          requiredCredentialIds: ['forklift_operator_cert'],
        ),
        serverCredentialHoldings: const [
          {
            'credentialId': 'forklift_operator_cert',
            'has_photo': true,
            'imagePath': 'https://cdn.test/forklift.jpg',
          },
        ],
        serverCanViewDocuments: true,
      );

      final credential = snapshot.credentials.single;
      expect(credential.isHeld, isTrue);
      expect(credential.imagePath, 'https://cdn.test/forklift.jpg');
      expect(credential.canViewDocument, isTrue);
    });

    test('required credential missing from holdings shows as not held', () {
      final snapshot = SeekerResumeSnapshot.fromApplication(
        _application(
          status: HiringApplicationStatus.applied,
          requiredCredentialIds: ['health_certificate'],
        ),
        serverCredentialHoldings: const [],
        serverCanViewDocuments: false,
      );

      final credential = snapshot.credentials.single;
      expect(credential.isHeld, isFalse);
      expect(credential.imagePath, isNull);
    });

    test(
        'without required ids, lists only holdings with has_photo true '
        'and uses customLabel when present', () {
      final snapshot = SeekerResumeSnapshot.fromApplication(
        _application(status: HiringApplicationStatus.scheduled),
        serverCredentialHoldings: const [
          {
            'credentialId': 'custom_123',
            'customLabel': '지게차 특별 이수증',
            'has_photo': true,
            'imagePath': 'https://cdn.test/custom.jpg',
          },
          {'credentialId': 'no_photo_cert', 'has_photo': false},
        ],
        serverCanViewDocuments: true,
      );

      expect(snapshot.credentials, hasLength(1));
      final credential = snapshot.credentials.single;
      expect(credential.credentialId, 'custom_123');
      expect(credential.label, '지게차 특별 이수증');
      expect(credential.isHeld, isTrue);
    });
  });
}
