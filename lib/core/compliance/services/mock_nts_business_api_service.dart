import 'package:map/core/compliance/domain/business_registration_number.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/domain/business_verification_result.dart';

/// 국세청/공공데이터 사업자 상태 조회 결과
class NtsBusinessLookupResult {
  const NtsBusinessLookupResult({
    required this.valid,
    required this.companyName,
    required this.industryName,
    required this.businessStatus,
    required this.entityTypeLabel,
    this.apiSource = 'mock_nts',
  });

  final bool valid;
  final String companyName;
  final String industryName;
  final String businessStatus;
  final String entityTypeLabel;
  final String apiSource;

  factory NtsBusinessLookupResult.fromVerificationResult(
    BusinessVerificationResult result,
  ) {
    return NtsBusinessLookupResult(
      valid: result.verified,
      companyName: result.companyName,
      industryName: result.industryName,
      businessStatus: result.businessStatus,
      entityTypeLabel: result.entityTypeLabel,
      apiSource: result.apiSource,
    );
  }
}

abstract class NtsBusinessApiService {
  Future<BusinessVerificationResult> verify(BusinessVerificationRequest request);

  @Deprecated('Use verify(BusinessVerificationRequest) with representative and opening date')
  Future<NtsBusinessLookupResult> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
  });
}

/// MVP mock — 공공데이터 API 키 없을 때 개발용.
///
/// 테스트용 유효 조합 (체크섬 통과 BRN):
/// - 사업자번호 `1234567891`
/// - 개업일자 `20200101`
/// - 대표자명 `홍길동`
/// - BRN 끝 4자리 `9991` → 인력공급업(관리자 검토 대상)
/// - BRN 끝 4자리 `8881` → 휴업 상태 시뮬레이션
class MockNtsBusinessApiService implements NtsBusinessApiService {
  const MockNtsBusinessApiService();

  static const devBrn = '1234567891';
  static const devOpeningDate = '20200101';
  static const devRepresentativeName = '홍길동';

  @override
  Future<BusinessVerificationResult> verify(
    BusinessVerificationRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final validationError = request.validate();
    if (validationError != null) {
      return BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.invalidFormat,
        failureMessage: validationError,
        apiSource: 'mock_nts',
      );
    }

    final brn = request.normalizedBrn;
    if (brn.endsWith('8881')) {
      return const BusinessVerificationResult(
        verified: false,
        businessStatus: '휴업',
        businessStatusCode: '02',
        failureReason: BusinessVerificationFailureReason.suspendedBusiness,
        failureMessage: '휴업 상태의 사업자입니다.',
        apiSource: 'mock_nts',
        ntsMatched: true,
      );
    }
    if (brn.endsWith('7771')) {
      return const BusinessVerificationResult(
        verified: false,
        businessStatus: '폐업',
        businessStatusCode: '03',
        failureReason: BusinessVerificationFailureReason.closedBusiness,
        failureMessage: '폐업 상태의 사업자입니다.',
        apiSource: 'mock_nts',
        ntsMatched: true,
      );
    }

    final matchesDevCredentials = brn == devBrn &&
        request.normalizedOpeningDate == devOpeningDate &&
        request.representativeName.trim() == devRepresentativeName;

    if (!matchesDevCredentials &&
        !(brn.endsWith('9991') &&
            request.normalizedOpeningDate == devOpeningDate &&
            request.representativeName.trim() == devRepresentativeName)) {
      return const BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.infoMismatch,
        failureMessage:
            '입력하신 정보가 국세청 등록 정보와 일치하지 않습니다. (개발 모드: $devBrn · $devOpeningDate · $devRepresentativeName)',
        apiSource: 'mock_nts',
      );
    }

    final isOutsourcing = brn.endsWith('9991');
    final isCorp = brn.startsWith('1') || brn.startsWith('2');
    return BusinessVerificationResult(
      verified: true,
      companyName: request.companyName.trim(),
      industryName: isOutsourcing ? '인력공급업' : '화물운송 및 물류대행',
      businessStatus: '계속사업자',
      businessStatusCode: '01',
      entityTypeLabel: isCorp ? '법인' : '개인사업자',
      apiSource: 'mock_nts',
      ntsMatched: false,
    );
  }

  @override
  Future<NtsBusinessLookupResult> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
  }) async {
    final brn = businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final result = await verify(
      BusinessVerificationRequest(
        businessRegistrationNumber: brn,
        representativeName: devRepresentativeName,
        openingDate: devOpeningDate,
        companyName: companyName,
      ),
    );
    if (!BusinessRegistrationNumber.isValidChecksum(brn)) {
      return const NtsBusinessLookupResult(
        valid: false,
        companyName: '',
        industryName: '',
        businessStatus: 'invalid',
        entityTypeLabel: '',
      );
    }
    return NtsBusinessLookupResult.fromVerificationResult(result);
  }
}
