/// 외부 채용 플랫폼 — 공고 가져오기 소스
enum ExternalJobPostPlatform {
  albamon('알바몬', 'albamon.com'),
  albacheon('알바천국', 'albacheon.com'),
  incruit('인크루트', 'incruit.com'),
  dongnealba('동네알바', 'dongnealba.com'),
  karrot('당근알바', 'daangn.com'),
  unknown('기타 사이트', '');

  const ExternalJobPostPlatform(this.label, this.hostHint);

  final String label;
  final String hostHint;

  static ExternalJobPostPlatform detectFromUrl(String url) {
    final lower = url.trim().toLowerCase();
    for (final platform in ExternalJobPostPlatform.values) {
      if (platform == ExternalJobPostPlatform.unknown) continue;
      if (lower.contains(platform.hostHint)) return platform;
    }
    if (lower.contains('albamon')) return ExternalJobPostPlatform.albamon;
    if (lower.contains('alba') && lower.contains('천국')) {
      return ExternalJobPostPlatform.albacheon;
    }
    if (lower.contains('당근') ||
        lower.contains('daangn') ||
        lower.contains('karrot')) {
      return ExternalJobPostPlatform.karrot;
    }
    return ExternalJobPostPlatform.unknown;
  }
}
