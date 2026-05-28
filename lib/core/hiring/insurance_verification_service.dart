import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/permanent_commission_policy.dart';

class InsuranceVerificationResult {
  const InsuranceVerificationResult({
    required this.success,
    required this.log,
    this.message,
  });

  final bool success;
  final InsuranceVerificationLog log;
  final String? message;
}

/// 건강보험 자격득실 — 간편인증(MVP: 네이버·토스·PASS 연동 예정)
class InsuranceVerificationService {
  bool companyNameMatches(String workplaceName, String employerCompanyName) {
    final normalizedWorkplace =
        _normalizeCompanyName(workplaceName);
    final normalizedEmployer = _normalizeCompanyName(employerCompanyName);
    if (normalizedWorkplace.isEmpty || normalizedEmployer.isEmpty) {
      return false;
    }
    return normalizedWorkplace.contains(normalizedEmployer) ||
        normalizedEmployer.contains(normalizedWorkplace);
  }

  String _normalizeCompanyName(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('(주)', '')
        .replaceAll('주식회사', '')
        .toLowerCase();
  }

  InsuranceVerificationResult verify({
    required String employmentId,
    required String employerCompanyName,
    required String workplaceNameFromCertificate,
    required bool currentlyEmployed,
    required DateTime now,
  }) {
    final matched =
        companyNameMatches(workplaceNameFromCertificate, employerCompanyName);
    final success = matched && currentlyEmployed;

    final log = InsuranceVerificationLog(
      id: 'ins_${now.millisecondsSinceEpoch}',
      employmentId: employmentId,
      workplaceName: workplaceNameFromCertificate.trim(),
      employerCompanyName: employerCompanyName.trim(),
      companyNameMatched: matched,
      employedConfirmed: currentlyEmployed,
      verifiedAt: now,
      expiresAt: now.add(
        const Duration(days: PermanentCommissionPolicy.verificationValidityDays),
      ),
      status: success
          ? InsuranceVerificationStatus.verified
          : InsuranceVerificationStatus.rejected,
      rejectionReason: success
          ? null
          : !matched
              ? '사업장명이 고용주 회사명과 일치하지 않습니다.'
              : '현재 재직 중 상태가 확인되지 않았습니다.',
    );

    return InsuranceVerificationResult(
      success: success,
      log: log,
      message: success
          ? '건강보험 간편인증이 완료되었습니다.'
          : log.rejectionReason,
    );
  }
}
