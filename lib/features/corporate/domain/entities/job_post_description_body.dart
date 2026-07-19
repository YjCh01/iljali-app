import 'dart:convert';

/// 공고 상세 본문 — 제목·급여·일정과 분리된 업무 내용 영역
class JobPostDescriptionBody {
  const JobPostDescriptionBody({
    this.text = '',
    this.html = '',
    this.imageUrls = const [],
    this.sourceUrl,
    this.sourceOwnershipConfirmedAt,
  });

  final String text;
  final String html;
  final List<String> imageUrls;

  /// 외부 URL에서 가져와 작성한 경우의 원본 URL
  final String? sourceUrl;

  /// 본인 회사가 게시한 공고임을 확인(체크박스)한 시각 — 분쟁 대비 기록용
  final DateTime? sourceOwnershipConfirmedAt;

  bool get hasContent =>
      text.trim().isNotEmpty ||
      html.trim().isNotEmpty ||
      imageUrls.isNotEmpty;

  /// 지도 콜아웃 snippet — 텍스트 첫 줄만 (이미지/HTML만이면 비움)
  String get calloutSnippet {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split('\n').first.trim();
  }

  /// 레거시 `job_description` · 검색·분류용 plain fallback
  String get legacyPlainText {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final stripped = stripHtmlTags(html);
    if (stripped.isNotEmpty) return stripped;
    if (imageUrls.isNotEmpty) return '이미지 공고';
    return '';
  }

  Map<String, dynamic> toJson() => {
        if (text.isNotEmpty) 'text': text,
        if (html.isNotEmpty) 'html': html,
        if (imageUrls.isNotEmpty) 'images': imageUrls,
        if (sourceUrl != null && sourceUrl!.isNotEmpty) 'source_url': sourceUrl,
        if (sourceOwnershipConfirmedAt != null)
          'source_ownership_confirmed_at':
              sourceOwnershipConfirmedAt!.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory JobPostDescriptionBody.fromJson(dynamic raw) {
    if (raw == null) return const JobPostDescriptionBody();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const JobPostDescriptionBody();
      try {
        return JobPostDescriptionBody.fromMap(
          jsonDecode(trimmed) as Map<String, dynamic>,
        );
      } on Object {
        return JobPostDescriptionBody(text: raw);
      }
    }
    if (raw is Map) {
      return JobPostDescriptionBody.fromMap(Map<String, dynamic>.from(raw));
    }
    return const JobPostDescriptionBody();
  }

  factory JobPostDescriptionBody.fromMap(Map<String, dynamic> map) {
    final html = map['html'] as String? ?? '';
    var imageUrls = (map['images'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    if (imageUrls.isEmpty && html.isNotEmpty) {
      imageUrls = extractImageUrlsFromHtml(html);
    }
    final confirmedAtRaw = map['source_ownership_confirmed_at'] as String?;
    return JobPostDescriptionBody(
      text: map['text'] as String? ?? '',
      html: html,
      imageUrls: imageUrls,
      sourceUrl: map['source_url'] as String?,
      sourceOwnershipConfirmedAt: confirmedAtRaw != null
          ? DateTime.tryParse(confirmedAtRaw)
          : null,
    );
  }

  /// HTML `<img src>` 추출 — images 필드 비어 있을 때 표시용
  static List<String> extractImageUrlsFromHtml(String html) {
    final re = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final out = <String>[];
    final seen = <String>{};
    for (final match in re.allMatches(html)) {
      final src = match.group(1)?.trim() ?? '';
      if (src.isEmpty || seen.contains(src)) continue;
      seen.add(src);
      out.add(src);
    }
    return out;
  }

  JobPostDescriptionBody copyWith({
    String? text,
    String? html,
    List<String>? imageUrls,
    String? sourceUrl,
    DateTime? sourceOwnershipConfirmedAt,
  }) {
    return JobPostDescriptionBody(
      text: text ?? this.text,
      html: html ?? this.html,
      imageUrls: imageUrls ?? this.imageUrls,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceOwnershipConfirmedAt:
          sourceOwnershipConfirmedAt ?? this.sourceOwnershipConfirmedAt,
    );
  }

  static String stripHtmlTags(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
