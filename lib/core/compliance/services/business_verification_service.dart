import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/domain/business_verification_result.dart';
import 'package:map/core/compliance/outsourcing_policy.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/compliance/services/nts_service_factory.dart';
import 'package:map/core/compliance/services/ocr_business_cross_check.dart';
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
    String? ocrRepReviewReason;
    if (certificateImageRef != null && certificateImageRef.isNotEmpty) {
      ocr = await _ocr.extractFromImage(
        imageRef: certificateImageRef,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
      );
      final ocrMismatch = OcrBusinessCrossCheck.detectMismatch(
        ocr: ocr,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
        expectedRepresentativeName: request.representativeName.trim(),
      );
      if (ocrMismatch != null) {
        if (OcrBusinessCrossCheck.isRepresentativeOnlyMismatch(ocrMismatch)) {
          ocrRepReviewReason = ocrMismatch;
        } else {
          throw BusinessVerificationException(ocrMismatch);
        }
      }
    }

    return _buildRecord(
      request: request,
      entityType: entityType,
      ntsResult: ntsResult,
      ocr: ocr,
      certificateImageRef: certificateImageRef,
      ocrRepReviewReason: ocrRepReviewReason,
    );
  }

  /// 국세청 미조회·신규 사업장 — BRN 형식만 확인하고 미인증(pending) 가입
  Future<VerifiedBusinessRecord> registerProvisionalBusiness({
    required BusinessVerificationRequest request,
    required BusinessEntityType entityType,
    String? certificateImageRef,
  }) async {
    final fieldError = request.validate();
    if (fieldError != null) {
      throw BusinessVerificationException(fieldError);
    }

    final hasCertificate =
        certificateImageRef != null && certificateImageRef.isNotEmpty;

    BusinessCertificateOcrResult? ocr;
    String? ocrMismatch;
    if (hasCertificate) {
      ocr = await _ocr.extractFromImage(
        imageRef: certificateImageRef!,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
      );
      ocrMismatch = OcrBusinessCrossCheck.detectMismatch(
        ocr: ocr,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
        expectedRepresentativeName: request.representativeName.trim(),
      );
    }

    final record = VerifiedBusinessRecord(
      businessRegistrationNumber: request.normalizedBrn,
      companyName: request.companyName.trim(),
      entityType: entityType,
      status: hasCertificate
          ? BusinessVerificationStatus.adminReviewRequired
          : BusinessVerificationStatus.pending,
      verifiedAt: DateTime.now(),
      representativeName: request.representativeName.trim(),
      certificateImageRef: certificateImageRef,
      registeredBusinessAddress: _ocrBusinessAddress(ocr),
      ocrConfidence: ocr?.confidence,
      ntsApiMatched: false,
      requiresAdminReview: hasCertificate,
      adminReviewReason: hasCertificate
          ? (ocrMismatch ??
              '신규·미조회 사업자 — 사업자등록증 검토 후 유료 서비스 이용 가능')
          : null,
      trustScore: hasCertificate ? (ocrMismatch != null ? 25 : 30) : 20,
    );

    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    if (hasCertificate) {
      await repo.addAbuseFlag({
        'type': 'provisional_certificate_review',
        'brn': request.normalizedBrn,
        'companyName': request.companyName.trim(),
        'severity': 'medium',
        'message': '미인증 가입 — 사업자등록증 검토 요청',
      });
    }
    return record;
  }

  /// 미인증 회원 — 사업자등록증 제출 → 관리자 검토 대기
  Future<VerifiedBusinessRecord> submitCertificateForReview({
    required BusinessVerificationRequest request,
    required BusinessEntityType entityType,
    required String certificateImageRef,
  }) async {
    final fieldError = request.validateForCertificateReview();
    if (fieldError != null) {
      throw BusinessVerificationException(fieldError);
    }
    if (certificateImageRef.trim().isEmpty) {
      throw BusinessVerificationException('사업자등록증을 업로드해 주세요.');
    }

    final ocr = await _ocr.extractFromImage(
      imageRef: certificateImageRef,
      expectedBrn: request.normalizedBrn,
      expectedCompanyName: request.companyName.trim(),
    );
    final ocrMismatch = OcrBusinessCrossCheck.detectMismatch(
      ocr: ocr,
      expectedBrn: request.normalizedBrn,
      expectedCompanyName: request.companyName.trim(),
      expectedRepresentativeName: request.representativeName.trim(),
    );

    final record = VerifiedBusinessRecord(
      businessRegistrationNumber: request.normalizedBrn,
      companyName: request.companyName.trim(),
      entityType: entityType,
      status: BusinessVerificationStatus.adminReviewRequired,
      verifiedAt: DateTime.now(),
      representativeName: request.representativeName.trim(),
      certificateImageRef: certificateImageRef,
      registeredBusinessAddress: _ocrBusinessAddress(ocr),
      ocrConfidence: ocr.confidence,
      ntsApiMatched: false,
      requiresAdminReview: true,
      adminReviewReason: ocrMismatch ??
          '사업자등록증 검토 후 유료 서비스 이용 가능',
      trustScore: ocrMismatch != null ? 25 : 35,
    );

    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    await repo.addAbuseFlag({
      'type': 'provisional_certificate_review',
      'brn': request.normalizedBrn,
      'companyName': request.companyName.trim(),
      'severity': 'medium',
      'message': '미인증 회원 — 사업자등록증 제출',
    });
    return record;
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
    String? ocrRepReviewReason,
  }) async {
    final industry = ntsResult.industryName.isNotEmpty
        ? ntsResult.industryName
        : (ocr?.industryName ?? '');
    final industryFlagged = OutsourcingPolicy.industryRequiresAdminReview(industry);
    final ocrRepFlagged = ocrRepReviewReason != null;
    final flagged = industryFlagged || ocrRepFlagged;

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
      registeredBusinessAddress: _ocrBusinessAddress(ocr),
      ocrConfidence: ocr?.confidence,
      ntsApiMatched: ntsResult.ntsMatched,
      requiresAdminReview: flagged,
      adminReviewReason: ocrRepFlagged
          ? ocrRepReviewReason
          : (industryFlagged
              ? '업종「$industry」— 인력공급·아웃소싱 의심, 관리자 승인 필요'
              : null),
      trustScore: flagged ? (ocrRepFlagged ? 55 : 40) : 100,
    );

    final repo = await _repo();
    await repo.saveBusinessRecord(record);
    if (flagged) {
      await repo.addAbuseFlag({
        'type': ocrRepFlagged ? 'ocr_representative_review' : 'industry_flag',
        'brn': request.normalizedBrn,
        'companyName': request.companyName.trim(),
        if (industryFlagged) 'industry': industry,
        'severity': industryFlagged ? 'high' : 'medium',
        if (ocrRepReviewReason != null) 'message': ocrRepReviewReason,
      });
    }
    return record;
  }

  Future<VerifiedBusinessRecord> _verifyRemote({
    required BusinessVerificationRequest request,
    required BusinessEntityType entityType,
    required String certificateImageRef,
  }) async {
    BusinessCertificateOcrResult? ocr;
    String? ocrRepReviewReason;
    if (certificateImageRef.isNotEmpty &&
        certificateImageRef != 'nts-identity-only') {
      ocr = await _ocr.extractFromImage(
        imageRef: certificateImageRef,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
      );
      final ocrMismatch = OcrBusinessCrossCheck.detectMismatch(
        ocr: ocr,
        expectedBrn: request.normalizedBrn,
        expectedCompanyName: request.companyName.trim(),
        expectedRepresentativeName: request.representativeName.trim(),
      );
      if (ocrMismatch != null) {
        if (OcrBusinessCrossCheck.isRepresentativeOnlyMismatch(ocrMismatch)) {
          ocrRepReviewReason = ocrMismatch;
        } else {
          throw BusinessVerificationException(ocrMismatch);
        }
      }
    }

    final record = await _apiClient.verifyBusiness(
      businessRegistrationNumber: request.normalizedBrn,
      companyName: request.companyName.trim(),
      representativeName: request.representativeName.trim(),
      openingDate: request.normalizedOpeningDate,
      entityType: entityType,
      certificateImageRef: certificateImageRef,
      ocrBrn: ocr?.businessRegistrationNumber,
      ocrCompanyName: ocr?.companyName,
      ocrRepresentativeName: ocr?.representativeName,
      ocrConfidence: ocr?.confidence,
    );
    final stored = _ocrBusinessAddress(ocr) != null
        ? record.copyWith(registeredBusinessAddress: _ocrBusinessAddress(ocr))
        : record;
    final repo = await _repo();
    await repo.saveBusinessRecord(stored);
    if (stored.requiresAdminReview) {
      await repo.addAbuseFlag({
        'type': 'industry_flag',
        'brn': stored.businessRegistrationNumber,
        'companyName': request.companyName.trim(),
        'industry': stored.industryName,
        'severity': 'high',
      });
    }
    return stored;
  }

  String? _ocrBusinessAddress(BusinessCertificateOcrResult? ocr) {
    final value = ocr?.businessAddress?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

class BusinessVerificationException implements Exception {
  BusinessVerificationException(this.message);
  final String message;
  @override
  String toString() => message;
}
