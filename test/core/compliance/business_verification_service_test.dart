import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/services/business_verification_service.dart';
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/features/auth/domain/usecases/corporate_sign_up_verification_gate.dart';

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

    test('blocks handler step without verification', () {
      expect(gate.canProceedToHandler(hasVerifiedRecord: false), isFalse);
      expect(
        gate.handlerBlockedMessage(hasVerifiedRecord: false),
        contains('국세청'),
      );
    });

    test('allows complete only with verified record and profile', () {
      expect(
        gate.canCompleteSignUp(
          hasVerifiedRecord: true,
          hasAssignedProfile: true,
        ),
        isTrue,
      );
      expect(
        gate.canCompleteSignUp(
          hasVerifiedRecord: false,
          hasAssignedProfile: true,
        ),
        isFalse,
      );
    });
  });
}
