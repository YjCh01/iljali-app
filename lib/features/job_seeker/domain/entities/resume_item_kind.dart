/// 이력서·지원서 공개 항목
enum ResumeItemKind {
  education,
  experience,
  license,
  certification,
  selfIntroduction,
}

extension ResumeItemKindX on ResumeItemKind {
  String get label => switch (this) {
        ResumeItemKind.education => '학력',
        ResumeItemKind.experience => '경력',
        ResumeItemKind.license => '면허',
        ResumeItemKind.certification => '자격증',
        ResumeItemKind.selfIntroduction => '자기소개',
      };

  String get apiValue => name;

  static ResumeItemKind? fromApiValue(String? raw) {
    if (raw == null) return null;
    for (final kind in ResumeItemKind.values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }

  static List<ResumeItemKind> parseList(Iterable<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .map((e) => fromApiValue(e.toString()))
        .whereType<ResumeItemKind>()
        .toList();
  }

  static List<String> encodeList(Iterable<ResumeItemKind> kinds) =>
      kinds.map((k) => k.name).toList();
}
