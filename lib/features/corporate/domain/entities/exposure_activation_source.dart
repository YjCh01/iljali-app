/// 핀·정류장 노출 활성화 유형 — 프로모션 종료 시 [promo]만 회수
enum ExposureActivationSource {
  promo,
  credit,
  payment,
}

extension ExposureActivationSourceX on ExposureActivationSource {
  String get storageValue => name;

  static ExposureActivationSource? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return switch (raw) {
      'promo' => ExposureActivationSource.promo,
      'credit' => ExposureActivationSource.credit,
      'payment' => ExposureActivationSource.payment,
      _ => null,
    };
  }
}
