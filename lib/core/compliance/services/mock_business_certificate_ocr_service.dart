import 'package:map/core/compliance/services/business_certificate_address_extractor.dart';

/// 사업자등록증 OCR 결과 (MVP mock)
class BusinessCertificateOcrResult {
  const BusinessCertificateOcrResult({
    required this.businessRegistrationNumber,
    required this.companyName,
    required this.representativeName,
    required this.industryName,
    required this.confidence,
    required this.entityTypeHint,
    this.businessAddress,
  });

  final String businessRegistrationNumber;
  final String companyName;
  final String representativeName;
  final String industryName;
  final double confidence;
  final String entityTypeHint;
  /// 등록증상 사업장 소재지 (국세청 등록 주소)
  final String? businessAddress;
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
      // 대표자명은 사용자 입력·국세청 확인에 맡김 — placeholder면 OCR 교차검증이 항상 실패함
      representativeName: '',
      industryName: isOutsourcingDemo ? '인력공급 및 아웃소싱' : '물류·창고업',
      confidence: 0.94,
      entityTypeHint: brn.startsWith('1') ? 'corporation' : 'soleProprietor',
      businessAddress: '경기도 화성시 동탄대로 123',
    );
  }
}
