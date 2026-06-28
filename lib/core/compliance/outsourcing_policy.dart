/// 아웃소싱·인력공급 업종 차단 정책
abstract final class OutsourcingPolicy {
  static const flaggedIndustryKeywords = [
    '인력공급',
    '인력 공급',
    '파견',
    '아웃소싱',
    '아웃 소싱',
    '인재파견',
    '인재 파견',
    '용역',
    '도급',
    '헤드헌팅',
    '채용대행',
  ];

  static const termsTitle = '아웃소싱·인력공급 이용 제한 약관';

  /// 전문: `assets/legal/07_outsourcing_restrictions.md` (LegalDocumentCatalog)
  static const termsAssetPath =
      'assets/legal/07_outsourcing_restrictions.md';

  static bool industryRequiresAdminReview(String? industryName) {
    if (industryName == null || industryName.isEmpty) return false;
    final normalized = industryName.replaceAll(' ', '');
    for (final keyword in flaggedIndustryKeywords) {
      if (normalized.contains(keyword.replaceAll(' ', ''))) return true;
    }
    return false;
  }
}
