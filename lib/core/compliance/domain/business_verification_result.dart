/// 국세청 사업자 진위·상태 확인 결과
enum BusinessVerificationFailureReason {
  invalidFormat,
  infoMismatch,
  notRegistered,
  closedBusiness,
  suspendedBusiness,
  apiUnavailable,
  apiError,
}

class BusinessVerificationResult {
  const BusinessVerificationResult({
    required this.verified,
    this.companyName = '',
    this.industryName = '',
    this.businessStatus = '',
    this.businessStatusCode = '',
    this.entityTypeLabel = '',
    this.apiSource = 'unknown',
    this.failureReason,
    this.failureMessage,
    this.ntsMatched = false,
  });

  final bool verified;
  final String companyName;
  final String industryName;
  final String businessStatus;
  final String businessStatusCode;
  final String entityTypeLabel;
  final String apiSource;
  final BusinessVerificationFailureReason? failureReason;
  final String? failureMessage;
  final bool ntsMatched;

  String get userMessage {
    if (verified) return '사업자 정보가 확인되었습니다.';
    if (failureMessage != null && failureMessage!.isNotEmpty) {
      return failureMessage!;
    }
    return switch (failureReason) {
      BusinessVerificationFailureReason.invalidFormat =>
        '사업자등록번호 형식이 올바르지 않습니다.',
      BusinessVerificationFailureReason.infoMismatch =>
        '입력하신 정보가 국세청 등록 정보와 일치하지 않습니다. 사업자등록증의 개업연월일·대표자명을 확인해 주세요.',
      BusinessVerificationFailureReason.notRegistered =>
        '국세청에 등록되지 않은 사업자등록번호입니다.',
      BusinessVerificationFailureReason.closedBusiness =>
        '폐업 또는 휴업 상태의 사업자입니다. 가입할 수 없습니다.',
      BusinessVerificationFailureReason.suspendedBusiness =>
        '현재 가입할 수 없는 사업자 상태입니다.',
      BusinessVerificationFailureReason.apiUnavailable =>
        '사업자 확인 서비스를 일시적으로 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
      BusinessVerificationFailureReason.apiError =>
        '사업자 확인 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      null => '사업자 확인에 실패했습니다.',
    };
  }

  factory BusinessVerificationResult.fromOdcloudValidateItem(
    Map<String, dynamic> item, {
    required String fallbackCompanyName,
    required String apiSource,
  }) {
    final valid = item['valid']?.toString() ?? '02';
    final validMsg = item['valid_msg']?.toString() ?? '';
    if (valid != '01') {
      return BusinessVerificationResult(
        verified: false,
        failureReason: valid == '02'
            ? BusinessVerificationFailureReason.infoMismatch
            : BusinessVerificationFailureReason.notRegistered,
        failureMessage: validMsg.isNotEmpty
            ? validMsg
            : '입력하신 정보가 국세청 등록 정보와 일치하지 않습니다.',
        apiSource: apiSource,
      );
    }

    final status = item['status'];
    if (status is Map<String, dynamic>) {
      final statusCode = status['b_stt_cd']?.toString() ?? '';
      final statusLabel = status['b_stt']?.toString() ?? '';
      final inactive = statusCode == '02' ||
          statusCode == '03' ||
          statusLabel.contains('폐업') ||
          statusLabel.contains('휴업');
      if (inactive) {
        return BusinessVerificationResult(
          verified: false,
          companyName: fallbackCompanyName,
          businessStatus: statusLabel,
          businessStatusCode: statusCode,
          failureReason: statusCode == '03' || statusLabel.contains('폐업')
              ? BusinessVerificationFailureReason.closedBusiness
              : BusinessVerificationFailureReason.suspendedBusiness,
          failureMessage: statusLabel.isNotEmpty
              ? '$statusLabel 상태의 사업자입니다.'
              : null,
          apiSource: apiSource,
          ntsMatched: true,
        );
      }

      final taxType = status['tax_type']?.toString() ?? '';
      return BusinessVerificationResult(
        verified: true,
        companyName: fallbackCompanyName,
        industryName: taxType,
        businessStatus: statusLabel,
        businessStatusCode: statusCode,
        entityTypeLabel: status['tax_type']?.toString() ?? '',
        apiSource: apiSource,
        ntsMatched: true,
      );
    }

    return BusinessVerificationResult(
      verified: true,
      companyName: fallbackCompanyName,
      apiSource: apiSource,
      ntsMatched: true,
    );
  }

  factory BusinessVerificationResult.fromOdcloudStatusItem(
    Map<String, dynamic> item, {
    required String fallbackCompanyName,
    required String apiSource,
  }) {
    final statusCode = item['b_stt_cd']?.toString() ?? '';
    final statusLabel = item['b_stt']?.toString() ?? '';
    if (statusLabel.contains('등록되지 않은') ||
        statusCode.isEmpty && statusLabel.isNotEmpty) {
      return BusinessVerificationResult(
        verified: false,
        failureReason: BusinessVerificationFailureReason.notRegistered,
        failureMessage: statusLabel.isNotEmpty
            ? statusLabel
            : '국세청에 등록되지 않은 사업자등록번호입니다.',
        apiSource: apiSource,
      );
    }
    if (statusCode == '02' ||
        statusCode == '03' ||
        statusLabel.contains('폐업') ||
        statusLabel.contains('휴업')) {
      return BusinessVerificationResult(
        verified: false,
        businessStatus: statusLabel,
        businessStatusCode: statusCode,
        failureReason: statusCode == '03' || statusLabel.contains('폐업')
            ? BusinessVerificationFailureReason.closedBusiness
            : BusinessVerificationFailureReason.suspendedBusiness,
        failureMessage: statusLabel.isNotEmpty
            ? '$statusLabel 상태의 사업자입니다.'
            : null,
        apiSource: apiSource,
        ntsMatched: true,
      );
    }
    return BusinessVerificationResult(
      verified: true,
      companyName: fallbackCompanyName,
      industryName: item['tax_type']?.toString() ?? '',
      businessStatus: statusLabel,
      businessStatusCode: statusCode,
      entityTypeLabel: item['tax_type']?.toString() ?? '',
      apiSource: apiSource,
      ntsMatched: true,
    );
  }
}
