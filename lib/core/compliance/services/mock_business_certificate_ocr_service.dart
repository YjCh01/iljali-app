/// 사업자등록증 OCR 결과 (MVP mock)
class BusinessCertificateOcrResult {
  const BusinessCertificateOcrResult({
    required this.businessRegistrationNumber,
    required this.companyName,
    required this.representativeName,
    required this.industryName,
    required this.confidence,
    required this.entityTypeHint,
  });

  final String businessRegistrationNumber;
  final String companyName;
  final String representativeName;
  final String industryName;
  final double confidence;
  final String entityTypeHint;
}

abstract class BusinessCertificateOcrService {
  Future<BusinessCertificateOcrResult> extractFromImage({
    required String imageRef,
    required String expectedBrn,
    required String expectedCompanyName,
  });
}

/// MVP — 실제 연동 시 Google Vision / Naver CLOVA OCR 등
class MockBusinessCertificateOcrService implements BusinessCertificateOcrService {
  const MockBusinessCertificateOcrService();

  @override
  Future<BusinessCertificateOcrResult> extractFromImage({
    required String imageRef,
    required String expectedBrn,
    required String expectedCompanyName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final brn = expectedBrn.replaceAll(RegExp(r'[^0-9]'), '');
    final isOutsourcingDemo = brn.endsWith('9999');
    return BusinessCertificateOcrResult(
      businessRegistrationNumber: brn,
      companyName: expectedCompanyName,
      representativeName: '대표자( OCR)',
      industryName: isOutsourcingDemo ? '인력공급 및 아웃소싱' : '물류·창고업',
      confidence: 0.94,
      entityTypeHint: brn.startsWith('1') ? 'corporation' : 'soleProprietor',
    );
  }
}
