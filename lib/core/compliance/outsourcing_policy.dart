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

  static const termsBody = '''
1. 본 서비스는 직접 고용(기업↔구직자) 중개를 목적으로 합니다.
2. 인력공급·파견·아웃소싱·용역 목적으로 PUSH·매칭 기능만 이용하는 행위를 금지합니다.
3. 해당 업종 사업자는 Enterprise 파트너십 가입 및 관리자 승인이 필수입니다.
4. BASIC(무과금) 플랜은 PUSH·공고 등록만 가능하며, 지원자 연락·채팅·즉시 확정은 완전히 차단됩니다. Starter 이상 파트너십 가입 후 이용 가능합니다.
5. 월정액 미결제 시 PUSH 매칭 후 오프플랫폼 유도·연락처 공유를 기술적으로 차단합니다.
6. 위반 시 계정 영구 정지 및 기존 매칭에 대한 성공 수수료 전액 청구 조항에 동의합니다.
''';

  static bool industryRequiresAdminReview(String? industryName) {
    if (industryName == null || industryName.isEmpty) return false;
    final normalized = industryName.replaceAll(' ', '');
    for (final keyword in flaggedIndustryKeywords) {
      if (normalized.contains(keyword.replaceAll(' ', ''))) return true;
    }
    return false;
  }
}
