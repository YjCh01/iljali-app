/// 기업별 담당자 4자리 코드 발급
abstract final class CorporateHandlerCodeGenerator {
  static const _minCode = 1001;
  static const _maxCode = 9999;

  static String nextCode(Iterable<String> existingCodes) {
    final used = existingCodes
        .map((code) => int.tryParse(code))
        .whereType<int>()
        .toSet();

    for (var value = _minCode; value <= _maxCode; value++) {
      if (!used.contains(value)) {
        return value.toString().padLeft(4, '0');
      }
    }
    throw StateError('담당자 코드를 더 이상 발급할 수 없습니다.');
  }
}
