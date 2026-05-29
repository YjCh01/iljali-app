/// 기업회원 가입 — 사업자 검증 완료 전 진행 차단
class CorporateSignUpVerificationGate {
  const CorporateSignUpVerificationGate();

  bool canProceedToHandler({required bool hasVerifiedRecord}) =>
      hasVerifiedRecord;

  bool canCompleteSignUp({
    required bool hasVerifiedRecord,
    required bool hasAssignedProfile,
  }) =>
      hasVerifiedRecord && hasAssignedProfile;

  String? handlerBlockedMessage({required bool hasVerifiedRecord}) {
    if (hasVerifiedRecord) return null;
    return '국세청 사업자 확인을 완료해야 담당자 정보를 등록할 수 있습니다.';
  }

  String? completeBlockedMessage({
    required bool hasVerifiedRecord,
    required bool hasAssignedProfile,
  }) {
    if (!hasVerifiedRecord) {
      return '미검증 사업자번호로는 기업 계정을 만들 수 없습니다.';
    }
    if (!hasAssignedProfile) return '담당자 코드 발급이 필요합니다.';
    return null;
  }
}
