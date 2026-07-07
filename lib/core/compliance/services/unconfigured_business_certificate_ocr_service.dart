import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';

/// OCR 미설정(실서비스) — 가짜 주소를 반환하지 않음
class UnconfiguredBusinessCertificateOcrService
    implements BusinessCertificateOcrService {
  const UnconfiguredBusinessCertificateOcrService();

  @override
  Future<BusinessCertificateOcrResult> extractFromImage({
    required String imageRef,
    required String expectedBrn,
    required String expectedCompanyName,
  }) async {
    final brn = expectedBrn.replaceAll(RegExp(r'[^0-9]'), '');
    return BusinessCertificateOcrResult(
      businessRegistrationNumber: brn,
      companyName: expectedCompanyName,
      representativeName: '',
      industryName: '',
      confidence: 0,
      entityTypeHint: brn.startsWith('1') ? 'corporation' : 'soleProprietor',
    );
  }
}
