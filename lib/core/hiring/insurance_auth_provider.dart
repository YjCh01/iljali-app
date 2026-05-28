/// 간편인증 수단 — Barocert/PortOne 통합
enum InsuranceAuthProvider {
  naver,
  kakao,
  toss,
  pass,
}

extension InsuranceAuthProviderX on InsuranceAuthProvider {
  String get apiValue => name;

  String get label => switch (this) {
        InsuranceAuthProvider.naver => '네이버',
        InsuranceAuthProvider.kakao => '카카오',
        InsuranceAuthProvider.toss => '토스',
        InsuranceAuthProvider.pass => 'PASS',
      };

  static InsuranceAuthProvider? fromApiValue(String? value) {
    if (value == null) return null;
    for (final item in InsuranceAuthProvider.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}
