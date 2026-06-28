/// 전자상거래법·스토어 심사용 사업자 신원 정보 (언리얼리 / 일자리)
abstract final class BusinessDisclosure {
  static const businessName = '언리얼리';
  static const serviceName = '일자리';
  static const registrationNumber = '537-58-01045';
  static const representative = '최영진';
  static const address = '경기도 용인시 수지구 용구대로 66, 205-202';
  static const email = 'iljariapp@gmail.com';
  static const phone = '1566-0000';

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
