import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/compliance/services/ocr_business_cross_check.dart';

void main() {
  const ocr = BusinessCertificateOcrResult(
    businessRegistrationNumber: '1234567891',
    companyName: '(주)일자리',
    representativeName: '홍길동',
    industryName: '물류',
    confidence: 0.94,
    entityTypeHint: 'corporation',
  );

  test('detectMismatch returns null when fields align', () {
    expect(
      OcrBusinessCrossCheck.detectMismatch(
        ocr: ocr,
        expectedBrn: '123-45-67891',
        expectedCompanyName: '일자리',
        expectedRepresentativeName: '홍길동',
      ),
      isNull,
    );
  });

  test('detectMismatch flags BRN mismatch', () {
    final reason = OcrBusinessCrossCheck.detectMismatch(
      ocr: ocr,
      expectedBrn: '9999999999',
      expectedCompanyName: '일자리',
    );
    expect(reason, contains('사업자번호'));
  });

  test('detectMismatch flags low confidence', () {
    final reason = OcrBusinessCrossCheck.detectMismatch(
      ocr: const BusinessCertificateOcrResult(
        businessRegistrationNumber: '1234567891',
        companyName: '일자리',
        representativeName: '홍길동',
        industryName: '물류',
        confidence: 0.5,
        entityTypeHint: 'corporation',
      ),
      expectedBrn: '1234567891',
      expectedCompanyName: '일자리',
    );
    expect(reason, contains('신뢰도'));
  });

  test('normalizes middle dot and spaces in representative names', () {
    expect(
      OcrBusinessCrossCheck.detectMismatch(
        ocr: const BusinessCertificateOcrResult(
          businessRegistrationNumber: '1234567891',
          companyName: '일자리',
          representativeName: '김 · 영희',
          industryName: '물류',
          confidence: 0.94,
          entityTypeHint: 'corporation',
        ),
        expectedBrn: '1234567891',
        expectedCompanyName: '일자리',
        expectedRepresentativeName: '김영희',
      ),
      isNull,
    );
  });

  test('allows one-character OCR typo for short Korean names', () {
    expect(
      OcrBusinessCrossCheck.detectMismatch(
        ocr: const BusinessCertificateOcrResult(
          businessRegistrationNumber: '1234567891',
          companyName: '일자리',
          representativeName: '홍길순',
          industryName: '물류',
          confidence: 0.94,
          entityTypeHint: 'corporation',
        ),
        expectedBrn: '1234567891',
        expectedCompanyName: '일자리',
        expectedRepresentativeName: '홍길동',
      ),
      isNull,
    );
  });

  test('mock OCR placeholder no longer blocks verification', () {
    expect(
      OcrBusinessCrossCheck.detectMismatch(
        ocr: const BusinessCertificateOcrResult(
          businessRegistrationNumber: '1234567891',
          companyName: '일자리',
          representativeName: '',
          industryName: '물류',
          confidence: 0.94,
          entityTypeHint: 'corporation',
        ),
        expectedBrn: '1234567891',
        expectedCompanyName: '일자리',
        expectedRepresentativeName: '최실제',
      ),
      isNull,
    );
  });

  test('isRepresentativeOnlyMismatch identifies rep errors', () {
    const reason =
        '등록증 OCR 대표자명이 입력값과 다릅니다 (OCR: 이타인). 국세청 확인이 완료되었다면 계속 진행되며, 관리자가 등록증을 검토합니다.';
    expect(OcrBusinessCrossCheck.isRepresentativeOnlyMismatch(reason), isTrue);
    expect(
      OcrBusinessCrossCheck.isRepresentativeOnlyMismatch('OCR 사업자번호 불일치'),
      isFalse,
    );
  });
}
