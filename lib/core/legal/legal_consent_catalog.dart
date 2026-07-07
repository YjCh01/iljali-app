/// 약관·개인정보·정책 버전 — 변경 시 재동의 게이트에 사용
abstract final class LegalConsentCatalog {
  static const termsVersion = '2026-06-29';
  static const privacyVersion = '2026-06-29';
  static const outsourcingPolicyVersion = '2026-01-01';
  static const electronicFinanceVersion = '2026-01-01';
  static const seekerDocumentConsentVersion = '2026-01-01';
  static const locationBasedVersion = '2026-01-01';

  static bool seekerDocumentConsentCurrent({
    String? documentConsentVersionAccepted,
  }) {
    return documentConsentVersionAccepted == seekerDocumentConsentVersion;
  }

  static bool seekerConsentCurrent({
    String? termsVersionAccepted,
    String? privacyVersionAccepted,
  }) {
    return termsVersionAccepted == termsVersion &&
        privacyVersionAccepted == privacyVersion;
  }

  static bool corporateConsentCurrent({
    String? termsVersionAccepted,
    String? privacyVersionAccepted,
    String? outsourcingPolicyVersionAccepted,
  }) {
    return termsVersionAccepted == termsVersion &&
        privacyVersionAccepted == privacyVersion &&
        outsourcingPolicyVersionAccepted == outsourcingPolicyVersion;
  }
}
