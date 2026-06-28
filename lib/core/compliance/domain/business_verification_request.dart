import 'package:map/core/compliance/domain/business_registration_number.dart';

/// 국세청 진위확인 API 요청 (공공데이터포털 / odcloud)
class BusinessVerificationRequest {
  const BusinessVerificationRequest({
    required this.businessRegistrationNumber,
    required this.representativeName,
    required this.openingDate,
    required this.companyName,
  });

  final String businessRegistrationNumber;
  final String representativeName;
  /// YYYYMMDD (사업자등록증 개업연월일)
  final String openingDate;
  final String companyName;

  String get normalizedBrn =>
      businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');

  String get normalizedOpeningDate =>
      openingDate.replaceAll(RegExp(r'[^0-9]'), '');

  String? validate() {
    final brnError =
        BusinessRegistrationNumber.formatErrorMessage(businessRegistrationNumber);
    if (brnError != null) return brnError;

    if (representativeName.trim().isEmpty) {
      return '대표자명을 입력해 주세요.';
    }
    if (normalizedOpeningDate.length != 8) {
      return '개업일자를 YYYYMMDD 형식(8자리)으로 입력해 주세요.';
    }
    final year = int.tryParse(normalizedOpeningDate.substring(0, 4));
    final month = int.tryParse(normalizedOpeningDate.substring(4, 6));
    final day = int.tryParse(normalizedOpeningDate.substring(6, 8));
    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return '개업일자 형식이 올바르지 않습니다. (예: 20200115)';
    }
    if (companyName.trim().isEmpty) {
      return '회사명을 입력해 주세요.';
    }
    return null;
  }

  /// 사업자등록증 제출·미인증 가입 — BRN·회사명만 확인 (개업일 미보유 시)
  String? validateForCertificateReview() {
    final brnError =
        BusinessRegistrationNumber.formatErrorMessage(businessRegistrationNumber);
    if (brnError != null) return brnError;
    if (companyName.trim().isEmpty) {
      return '회사명을 입력해 주세요.';
    }
    return null;
  }

  Map<String, dynamic> toNtsValidatePayload() => {
        'b_no': normalizedBrn,
        'start_dt': normalizedOpeningDate,
        'p_nm': representativeName.trim(),
        'p_nm2': '',
        'b_nm': companyName.trim(),
        'corp_no': '',
        'b_sector': '',
        'b_type': '',
        'b_adr': '',
      };
}
