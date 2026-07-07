/// QC·MVP 데모에 쓰이던 고정 주소 — 실서비스에서는 무시
abstract final class QcDemoAddresses {
  static const legacyHwaseongDongtan = '경기도 화성시 동탄대로 123';

  static const _legacyNormalized = <String>{
    '경기도화성시동탄대로123',
    '경기화성시동탄대로123',
    '화성시동탄대로123',
  };

  static bool isLegacyDemo(String? address) {
    if (address == null) return false;
    final trimmed = address.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == legacyHwaseongDongtan) return true;
    final normalized =
        trimmed.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return _legacyNormalized.contains(normalized);
  }
}
