/// 상시직(상용직) 수수료 정책 — 월급 5.5%, 30일 주기
abstract final class PermanentCommissionPolicy {
  static const commissionRate = 0.055;
  static const billingCycleDays = 30;
  static const initialVerificationDeadlineDays = 7;
  static const reauthReminderDaysBeforeExpiry = 5;
  static const verificationValidityDays = 30;
}
