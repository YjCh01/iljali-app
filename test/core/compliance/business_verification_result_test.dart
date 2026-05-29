import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/domain/business_verification_result.dart';

void main() {
  group('BusinessVerificationResult.fromOdcloudValidateItem', () {
    test('returns verified when valid=01 and continuing business', () {
      final result = BusinessVerificationResult.fromOdcloudValidateItem(
        {
          'valid': '01',
          'valid_msg': '',
          'status': {
            'b_stt_cd': '01',
            'b_stt': '계속사업자',
            'tax_type': '부가가치세 일반과세자',
          },
        },
        fallbackCompanyName: '(주)일자리',
        apiSource: 'odcloud',
      );

      expect(result.verified, isTrue);
      expect(result.ntsMatched, isTrue);
      expect(result.industryName, contains('부가가치세'));
    });

    test('returns mismatch when valid=02', () {
      final result = BusinessVerificationResult.fromOdcloudValidateItem(
        {
          'valid': '02',
          'valid_msg': '확인할 수 없습니다.',
        },
        fallbackCompanyName: '(주)일자리',
        apiSource: 'odcloud',
      );

      expect(result.verified, isFalse);
      expect(result.failureReason, BusinessVerificationFailureReason.infoMismatch);
      expect(result.userMessage, contains('확인할 수 없습니다'));
    });

    test('blocks closed business from nested status', () {
      final result = BusinessVerificationResult.fromOdcloudValidateItem(
        {
          'valid': '01',
          'status': {
            'b_stt_cd': '03',
            'b_stt': '폐업',
          },
        },
        fallbackCompanyName: '(주)일자리',
        apiSource: 'odcloud',
      );

      expect(result.verified, isFalse);
      expect(result.failureReason, BusinessVerificationFailureReason.closedBusiness);
    });
  });

  group('BusinessVerificationResult.fromOdcloudStatusItem', () {
    test('detects unregistered business', () {
      final result = BusinessVerificationResult.fromOdcloudStatusItem(
        {
          'b_stt': '국세청에 등록되지 않은 사업자등록번호입니다.',
        },
        fallbackCompanyName: '(주)일자리',
        apiSource: 'odcloud',
      );

      expect(result.verified, isFalse);
      expect(result.failureReason, BusinessVerificationFailureReason.notRegistered);
    });
  });
}
