import 'package:flutter/material.dart';

/// 약관 원문 마커: `[[REVIEW:변호사/대표 확인 사항]]내용[[/REVIEW]]`
final _reviewPattern = RegExp(
  r'\[\[REVIEW:([^\]]*)\]\]([\s\S]*?)\[\[/REVIEW\]\]',
);

class LegalDocumentParser {
  const LegalDocumentParser._();

  static List<InlineSpan> parseToSpans(
    String raw, {
    required TextStyle baseStyle,
    Color reviewBackground = const Color(0xFFFFF59D),
    Color reviewForeground = const Color(0xFF5D4037),
  }) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _reviewPattern.allMatches(raw)) {
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: raw.substring(cursor, match.start),
          style: baseStyle,
        ));
      }

      final note = match.group(1)?.trim() ?? '';
      final body = match.group(2) ?? '';
      final reviewText = note.isEmpty ? body : '[$note] $body';

      spans.add(TextSpan(
        text: reviewText,
        style: baseStyle.copyWith(
          backgroundColor: reviewBackground,
          color: reviewForeground,
          fontWeight: FontWeight.w600,
        ),
      ));

      cursor = match.end;
    }

    if (cursor < raw.length) {
      spans.add(TextSpan(
        text: raw.substring(cursor),
        style: baseStyle,
      ));
    }

    return spans;
  }

  static String stripMarkers(String raw) =>
      raw.replaceAllMapped(_reviewPattern, (m) => m.group(2) ?? '');

  static List<({String note, String body})> reviewSections(String raw) {
    return _reviewPattern
        .allMatches(raw)
        .map((m) => (note: m.group(1)?.trim() ?? '', body: m.group(2) ?? ''))
        .toList();
  }
}
