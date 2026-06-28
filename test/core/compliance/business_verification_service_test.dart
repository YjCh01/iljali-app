import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/services/business_verification_service.dart';
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/features/auth/domain/usecases/corporate_sign_up_verification_gate.dart';

final _fixedTime = DateTime(2026, 1, 1);

void main() {
  group('MockNtsBusinessApiService', () {
    const nts = MockNtsBusinessApiService();

    test('accepts dev credentials', () async {
      final result = await nts.verify(
        const BusinessVerificationRequest(
          businessRegistrationNumber: MockNtsBusinessApiService.devBrn,
          representativeName: MockNtsBusinessApiService.devRepresentativeName,
          openingDate: MockNtsBusinessApiService.devOpeningDate,
          companyName: '(주)테스트',
        ),
      );
      expect(result.verified, isTrue);
    });

    test('rejects wrong representative name', () async {
      final result = await nts.verify(
        const BusinessVerificationRequest(
          businessRegistrationNumber: MockNtsBusinessApiService.devBrn,
          representativeName: '김철수',
          openingDate: MockNtsBusinessApiService.devOpeningDate,
          companyName: '(주)테스트',
        ),
      );
      expect(result.verified, isFalse);
      expect(result.failureReason, isNotNull);
    });
  });

  group('BusinessVerificationService', () {
    test('verifyBusinessIdentity succeeds with mock NTS and certificate', () async {
      final service = BusinessVerificationService(
        nts: const MockNtsBusinessApiService(),
      );
      final record = await service.verifyBusinessIdentity(
        request: const BusinessVerificationRequest(
          businessRegistrationNumber: MockNtsBusinessApiService.devBrn,
          representativeName: MockNtsBusinessApiService.devRepresentativeName,
          openingDate: MockNtsBusinessApiService.devOpeningDate,
          companyName: '(주)일자리',
        ),
        entityType: BusinessEntityType.corporation,
        certificateImageRef: 'mock://certificate/test.jpg',
      );
      expect(record.businessRegistrationNumber, MockNtsBusinessApiService.devBrn);
      expect(record.status.name, 'verified');
    });

    test('verifyBusinessIdentity succeeds with mock NTS', () async {
      final service = BusinessVerificationService(
        nts: const MockNtsBusinessApiService(),
      );
      final record = await service.verifyBusinessIdentity(
        request: const BusinessVerificationRequest(
          businessRegistrationNumber: MockNtsBusinessApiService.devBrn,
          representativeName: MockNtsBusinessApiService.devRepresentativeName,
          openingDate: MockNtsBusinessApiService.devOpeningDate,
          companyName: '(주)일자리',
        ),
        entityType: BusinessEntityType.corporation,
      );
      expect(record.businessRegistrationNumber, MockNtsBusinessApiService.devBrn);
      expect(record.status.name, 'verified');
    });

    test('verifyBusinessIdentity throws on invalid BRN checksum', () async {
      final service = BusinessVerificationService(
        nts: const MockNtsBusinessApiService(),
      );
      expect(
        () => service.verifyBusinessIdentity(
          request: const BusinessVerificationRequest(
            businessRegistrationNumber: '1234567890',
            representativeName: MockNtsBusinessApiService.devRepresentativeName,
            openingDate: MockNtsBusinessApiService.devOpeningDate,
            companyName: '(주)일자리',
          ),
          entityType: BusinessEntityType.corporation,
        ),
        throwsA(isA<BusinessVerificationException>()),
      );
    });
  });

  group('CorporateSignUpVerificationGate', () {
    const gate = CorporateSignUpVerificationGate();

    test('blocks handler step without any verification record', () {
      expect(gate.canProceedToHandler(record: null), isFalse);
      expect(
        gate.handlerBlockedMessage(record: null),
        contains('미인증'),
      );
    });

    test('allows handler with provisional pending record', () {
      final record = VerifiedBusinessRecord(
        businessRegistrationNumber: '1234567891',
        companyName: '(주)신규',
        entityType: BusinessEntityType.corporation,
        status: BusinessVerificationStatus.pending,
        verifiedAt: _fixedTime,
      );
      expect(gate.canProceedToHandler(record: record), isTrue);
    });

    test('allows complete with verified or provisional record and profile', () {
      final verified = VerifiedBusinessRecord(
        businessRegistrationNumber: '1234567891',
        companyName: '(주)일자리',
        entityType: BusinessEntityType.corporation,
        status: BusinessVerificationStatus.verified,
        verifiedAt: _fixedTime,
      );
      final pending = VerifiedBusinessRecord(
        businessRegistrationNumber: '9876543210',
        companyName: '(주)신규',
        entityType: BusinessEntityType.corporation,
        status: BusinessVerificationStatus.pending,
        verifiedAt: _fixedTime,
      );
      expect(
        gate.canCompleteSignUp(record: verified, hasAssignedProfile: true),
        isTrue,
      );
      expect(
        gate.canCompleteSignUp(record: pending, hasAssignedProfile: true),
        isTrue,
      );
      expect(
        gate.canCompleteSignUp(record: verified, hasAssignedProfile: false),
        isFalse,
      );
    });
  });
}
