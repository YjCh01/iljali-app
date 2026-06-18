/// 유료 노출 활성화 시 차감할 이용권 종류
enum ExposureActivationCreditMode {
  /// 알림핀·정류장 노출만 (19,900)
  exposureOnly,

  /// 노출 + 해당 위치 반경 1km PUSH (35,900)
  exposureWithPush,
}

extension ExposureActivationCreditModeX on ExposureActivationCreditMode {
  String get label => switch (this) {
        ExposureActivationCreditMode.exposureOnly => '노출만',
        ExposureActivationCreditMode.exposureWithPush => '노출 + PUSH',
      };

  String get description => switch (this) {
        ExposureActivationCreditMode.exposureOnly =>
          '지도 노출 · 적용 후 D+1 23:59:59까지',
        ExposureActivationCreditMode.exposureWithPush =>
          '지도 노출 + 해당 위치 1km PUSH 1회',
      };
}
