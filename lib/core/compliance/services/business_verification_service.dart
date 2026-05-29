import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/domain/business_verification_result.dart';
import 'package:map/core/compliance/outsourcing_policy.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/compliance/services/nts_service_factory.dart';
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/services/ocr_service_factory.dart';
import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/core/config/env_config.dart';

/// 사업자등록증 OCR + 국세청(공공데이터) 진위확인 오케스트레이션
class BusinessVerificationService {
  BusinessVerificationService({
    BusinessCertificateOcrService? ocr,
    NtsBusinessApiService? nts,
    ComplianceRepository? repository,
    ComplianceApiClient? apiClient,
  })  : _ocr = ocr ?? OcrServiceFactory.create(),
        _nts = nts ?? NtsServiceFactory.create(),
        _repository = repository,
        _apiClient = apiClient ?? ComplianceApiClient();

  final BusinessCertificateOcrService _ocr;
  final NtsBusinessApiService _nts;
  ComplianceRepository? _repository;
  final ComplianceApiClient _apiClient;

  Future<ComplianceRepository> _repo() async =>
      _repository ??= await ComplianceRepository.create();

  /// 국세청 진위확인 — 사업자번호·대표자명·개업일자 (필수)
  Future<VerifiedBusinessRecord> verifyBusinessIdentity({
    required BusinessVerificationRequest request,
    required BusinessEntityType entityType,
    String? certificateImageRef,
  }) async {
    final fieldError = request.validate();
    if (fieldError != null) {
      throw BusinessVerificationException(fieldError);
    }

    if (EnvConfig.isComplianceApiEnabled && _apiClient.isEnabled) {
      return _verifyRemote(
        request: request,
        entityType: entityType,
        certificateImageRef: certificateImageRef ?? 'nts-identity-only',
      );
    }

    final ntsResult = await _nts.verify(request);
    if (!ntsResult.verified) {
      throw BusinessVerificationException(ntsResult.userMessage);
    }

    BusinessCertificateOcrResult? ocr;
    if (certificateImageRef != null && certificateImageRef.isNotEmpty) {
      ocr = await _ocr.extractFromImage(
        imageRef: certificateImageRef,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
      );
      if (ocr.businessRegistrationNumber != request.normalizedBrn) {
        throw BusinessVerificationException(
          'OCR 사업자번호가 입력값과 일치하지 않습니다.',
        );
      }
    }

    return _buildRecord(
      request: request,
      entityType: entityType,
      ntsResult: ntsResult,
      ocr: ocr,
      certificateImageRef: certificateImageRef,
    );
  }

  Future<VerifiedBusinessRecord> verifyWithCertificate({
    required String businessRegistrationNumber,
    required String companyName,
    required BusinessEntityType entityType,
    required String certificateImageRef,
    String? representativeName,
    String? openingDate,
  }) {
    return verifyBusinessIdentity(
      request: BusinessVerificationRequest(
        businessRegistrationNumber: businessRegistrationNumber,
        representativeName:
            representativeName ?? MockNtsBusinessApiService.devRepresentativeName,
        openingDate: openingDate ?? MockNtsBusinessApiService.devOpeningDate,
        companyName: companyName,
      ),
      entityType: entityType,
      certificateImageRef: certificateImageRef,
    );
  }

  Future<VerifiedBusinessRecord> _buildRecord({
    required BusinessVerificationRequest request,
    required BusinessEntityType entityType,
    required BusinessVerificationResult ntsResult,
    BusinessCertificateOcrResult? ocr,
    String? certificateImageRef,
  }) async {
    final industry = ntsResult.industryName.isNotEmpty
        ? ntsResult.industryName
        : (ocr?.industryName ?? '');
    final flagged = OutsourcingPolicy.industryRequiresAdminReview(industry);

    final record = VerifiedBusinessRecord(
      businessRegistrationNumber: request.normalizedBrn,
      companyName: request.companyName.trim(),
      entityType: entityType,
      status: flagged
          ? BusinessVerificationStatus.adminReviewRequired
          : BusinessVerificationStatus.verified,
      verifiedAt: DateTime.now(),
      industryName: industry.isEmpty ? null : industry,
      representativeName:
          request.representativeName.trim().isEmpty
              ? ocr?.representativeName
              : request.representativeName.trim(),
      certificateImageRef: certificateImageRef,
      ocrConfidence: ocr?.confidence,
      ntsApiMatched: ntsResult.ntsMatched,
      requiresAdminReview: flagged,
      adminReviewReason: flagged
          ? '업종「$industry」— 인력공급·아웃소싱 의심, 관리자 승인 필요'
          : null,
      trustScore: flagged ? 40 : 100,
    );

    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    if (flagged) {
      await repo.addAbuseFlag({
        'type': 'industry_flag',
        'brn': request.normalizedBrn,
        'companyName': request.companyName.trim(),
        'industry': industry,
        'severity': 'high',
      });
    }
    return record;
  }

  Future<VerifiedBusinessRecord> _verifyRemote({
    required BusinessVerificationRequest request,
    required BusinessEntityType entityType,
    required String certificateImageRef,
  }) async {
    final record = await _apiClient.verifyBusiness(
      businessRegistrationNumber: request.normalizedBrn,
      companyName: request.companyName.trim(),
      representativeName: request.representativeName.trim(),
      openingDate: request.normalizedOpeningDate,
      entityType: entityType,
      certificateImageRef: certificateImageRef,
    );
    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    if (record.requiresAdminReview) {
      await repo.addAbuseFlag({
        'type': 'industry_flag',
        'brn': record.businessRegistrationNumber,
        'companyName': request.companyName.trim(),
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
