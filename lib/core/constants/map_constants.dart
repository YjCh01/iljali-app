import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 네이버 지도 관련 상수
abstract final class MapConstants {
  /// 물류센터 밀집 지역 중심 (강남·삼성·코엑스 일대)
  static const NLatLng warehouseAreaCenter = NLatLng(37.5128, 127.0471);

  /// Naver Maps 기준 서울(37.5°N) 축척 ~100m — 정류장·알림핀 배치 기본
  static const double scale100mZoom = 17;

  /// @Deprecated — [scale100mZoom]과 동일. 기존 참조 호환용.
  static const double warehouseAreaZoom = scale100mZoom;

  static const NLatLng defaultCenter = warehouseAreaCenter;
  static const double defaultZoom = scale100mZoom;
}
