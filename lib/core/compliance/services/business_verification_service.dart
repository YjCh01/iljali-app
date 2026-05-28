import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/outsourcing_policy.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/compliance/services/ocr_service_factory.dart';
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/core/config/env_config.dart';

/// 사업자등록증 OCR + 국세청 검증 오케스트레이션
class BusinessVerificationService {
  BusinessVerificationService({
    BusinessCertificateOcrService? ocr,
    NtsBusinessApiService? nts,
    ComplianceRepository? repository,
    ComplianceApiClient? apiClient,
  })  : _ocr = ocr ?? OcrServiceFactory.create(),
        _nts = nts ?? const MockNtsBusinessApiService(),
        _repository = repository,
        _apiClient = apiClient ?? ComplianceApiClient();

  final BusinessCertificateOcrService _ocr;
  final NtsBusinessApiService _nts;
  ComplianceRepository? _repository;
  final ComplianceApiClient _apiClient;

  Future<ComplianceRepository> _repo() async =>
      _repository ??= await ComplianceRepository.create();

  Future<VerifiedBusinessRecord> verifyWithCertificate({
    required String businessRegistrationNumber,
    required String companyName,
    required BusinessEntityType entityType,
    required String certificateImageRef,
  }) async {
    if (EnvConfig.isComplianceApiEnabled && _apiClient.isEnabled) {
      return _verifyRemote(
        businessRegistrationNumber: businessRegistrationNumber,
        companyName: companyName,
        entityType: entityType,
        certificateImageRef: certificateImageRef,
      );
    }

    final brn = businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final ocr = await _ocr.extractFromImage(
      imageRef: certificateImageRef,
      expectedBrn: brn,
      expectedCompanyName: companyName,
    );
    final nts = await _nts.verifyBusiness(
      businessRegistrationNumber: brn,
      companyName: companyName,
    );

    if (!nts.valid) {
      throw BusinessVerificationException('국세청 조회 결과 유효하지 않은 사업자입니다.');
    }
    if (ocr.businessRegistrationNumber != brn) {
      throw BusinessVerificationException('OCR 사업자번호가 입력값과 일치하지 않습니다.');
    }

    final industry = nts.industryName.isNotEmpty ? nts.industryName : ocr.industryName;
    final flagged = OutsourcingPolicy.industryRequiresAdminReview(industry);

    final record = VerifiedBusinessRecord(
      businessRegistrationNumber: brn,
      companyName: companyName,
      entityType: entityType,
      status: flagged
          ? BusinessVerificationStatus.adminReviewRequired
          : BusinessVerificationStatus.verified,
      verifiedAt: DateTime.now(),
      industryName: industry,
      representativeName: ocr.representativeName,
      certificateImageRef: certificateImageRef,
      ocrConfidence: ocr.confidence,
      ntsApiMatched: true,
      requiresAdminReview: flagged,
      adminReviewReason: flagged
          ? '업종「$industry」— 인력공급·아웃소싱 의심, Enterprise 가입·관리자 승인 필요'
          : null,
      trustScore: flagged ? 40 : 100,
    );

    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    if (flagged) {
      await repo.addAbuseFlag({
        'type': 'industry_flag',
        'brn': brn,
        'companyName': companyName,
        'industry': industry,
        'severity': 'high',
      });
    }
    return record;
  }

  Future<VerifiedBusinessRecord> _verifyRemote({
    required String businessRegistrationNumber,
    required String companyName,
    required BusinessEntityType entityType,
    required String certificateImageRef,
  }) async {
    final record = await _apiClient.verifyBusiness(
      businessRegistrationNumber: businessRegistrationNumber,
      companyName: companyName,
      entityType: entityType,
      certificateImageRef: certificateImageRef,
    );
    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    if (record.requiresAdminReview) {
      await repo.addAbuseFlag({
        'type': 'industry_flag',
        'brn': record.businessRegistrationNumber,
        'companyName': companyName,
        'industry': record.industryName,
        'severity': 'high',
      });
    }
    return record;
  }
}

class BusinessVerificationException implements Exception {
  BusinessVerificationException(this.message);
  final String message;
  @override
  String toString() => message;
}
