/// 셔틀 노선 지도 노출 유료 부가상품 (MVP)
abstract final class ShuttleRouteCatalog {
  static const productId = 'shuttle_route_overlay';
  static const productName = '셔틀 노선 지도 노출';
  static const priceKrw = 10000;

  static String get priceLabel =>
      '${priceKrw.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';

  static const mapOverlayLead =
      '구직자 지도에서 셔틀 경로·정류장을 표시합니다.';

  static const benefitLead =
      '셔틀버스 정류장과 주요 통근 거점 중심으로 공고를 노출할 경우, 지원율이 ';

  static const benefitHighlight = '최대 2.5배(150%↑)';

  static const benefitTail = ' 상승하는 효과를 기대할 수 있습니다.';

  static String get description =>
      '$mapOverlayLead $benefitLead$benefitHighlight$benefitTail';
}
