import 'package:map/core/compliance/verified_business_record.dart';

/// 기업회원 가입 — 국세청 검증 또는 미인증(provisional) 경로
class CorporateSignUpVerificationGate {
  const CorporateSignUpVerificationGate();

  bool canProceedToHandler({required VerifiedBusinessRecord? record}) =>
      record != null;

  bool canCompleteSignUp({
    required VerifiedBusinessRecord? record,
    required bool hasAssignedProfile,
  }) =>
      record != null && hasAssignedProfile;

  String? handlerBlockedMessage({required VerifiedBusinessRecord? record}) {
    if (record != null) return null;
    return '국세청 확인을 완료하거나, 미인증 회원으로 가입해 주세요.';
  }

  String? completeBlockedMessage({
    required VerifiedBusinessRecord? record,
    required bool hasAssignedProfile,
  }) {
    if (record == null) {
      return '사업자 확인 또는 미인증 가입을 완료해 주세요.';
    }
    if (!hasAssignedProfile) return '담당자 코드 발급이 필요합니다.';
    return null;
  }
}
