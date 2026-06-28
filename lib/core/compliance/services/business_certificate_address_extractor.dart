/// 사업자등록증 OCR 텍스트에서 사업장 소재지 추출
abstract final class BusinessCertificateAddressExtractor {
  static String? fromOcrLines(Iterable<String> lines) {
    final normalized = lines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (normalized.isEmpty) return null;

    for (var i = 0; i < normalized.length; i++) {
      final line = normalized[i];
      if (!_isAddressLabelLine(line)) continue;

      final inline = _afterColon(line);
      if (inline != null && looksLikeKoreanRoadAddress(inline)) {
        return inline;
      }
      for (var j = i + 1; j < normalized.length && j <= i + 2; j++) {
        final candidate = normalized[j];
        if (looksLikeKoreanRoadAddress(candidate)) return candidate;
      }
    }

    for (final line in normalized) {
      if (looksLikeKoreanRoadAddress(line) && !_isAddressLabelLine(line)) {
        return line;
      }
    }
    return null;
  }

  static bool _isAddressLabelLine(String line) {
    final compact = line.replaceAll(' ', '');
    return compact.contains('사업장소재지') ||
        compact.contains('본점소재지') ||
        compact.contains('사업장주소') ||
        compact.contains('사업자소재지');
  }

  static String? _afterColon(String line) {
    final match = RegExp(r'[:：]\s*(.+)').firstMatch(line);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static bool looksLikeKoreanRoadAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 8) return false;
    if (!RegExp(r'(특별|광역|특별자치|도)').hasMatch(trimmed) &&
        !trimmed.startsWith('서울') &&
        !trimmed.startsWith('부산') &&
        !trimmed.startsWith('대구') &&
        !trimmed.startsWith('인천') &&
        !trimmed.startsWith('광주') &&
        !trimmed.startsWith('대전') &&
        !trimmed.startsWith('울산') &&
        !trimmed.startsWith('세종')) {
      return false;
    }
    return RegExp(r'(로|길|대로)\s*\d').hasMatch(trimmed) ||
        RegExp(r'\d+\s*(로|길|대로)').hasMatch(trimmed);
  }
}
