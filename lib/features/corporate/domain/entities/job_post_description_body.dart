import 'dart:convert';

/// 공고 상세 본문 — 제목·급여·일정과 분리된 업무 내용 영역
class JobPostDescriptionBody {
  const JobPostDescriptionBody({
    this.text = '',
    this.html = '',
    this.imageUrls = const [],
  });

  final String text;
  final String html;
  final List<String> imageUrls;

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
    return JobPostDescriptionBody(
      text: map['text'] as String? ?? '',
      html: map['html'] as String? ?? '',
      imageUrls: (map['images'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }

  JobPostDescriptionBody copyWith({
    String? text,
    String? html,
    List<String>? imageUrls,
  }) {
    return JobPostDescriptionBody(
      text: text ?? this.text,
      html: html ?? this.html,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  static String stripHtmlTags(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
