import 'dart:math';

/// 기업별 담당자 식별 코드 — 로그인용 아님, 사내 담당자 구분용
abstract final class CorporateHandlerCodeGenerator {
  static const codeLength = 6;

  /// 혼동하기 쉬운 0/O, 1/I/L 제외
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String nextCode(Iterable<String> existingCodes) {
    final used = existingCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();

    for (var attempt = 0; attempt < 128; attempt++) {
      final code = _randomCode();
      if (!used.contains(code)) return code;
    }
    throw StateError('담당자 코드를 더 이상 발급할 수 없습니다.');
  }

  static String _randomCode() {
    final random = Random.secure();
    return List.generate(
      codeLength,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }
}
