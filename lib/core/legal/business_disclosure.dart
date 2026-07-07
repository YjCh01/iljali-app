/// 전자상거래법·스토어 심사용 사업자 신원 정보 (아라컴퍼니 / 일자리)
abstract final class BusinessDisclosure {
  static const businessName = '아라컴퍼니';
  static const serviceName = '일자리';
  static const registrationNumber = '540-31-00894';
  static const representative = '최영진';
  static const address = '서울 송파구 오금로11길 55, 현대빌딩 2층 비즈센터';
  static const email = 'iljariapp@gmail.com';
  static const phone = '1644-5701';

  /// 공정거래위원회 사업자정보 공개 조회 (사업자등록번호)
  static String get ftcVerificationUrl =>
      'https://www.ftc.go.kr/www/selectBizCommView.do'
      '?searchCnd=BRNO&searchKrwd=${registrationNumber.replaceAll('-', '')}';

  static const List<String> footerLines = [
    '상호: $businessName · 서비스: $serviceName',
    '대표: $representative · 사업자등록번호: $registrationNumber',
    '주소: $address',
    '문의: $email (우선) · $phone',
  ];
}
