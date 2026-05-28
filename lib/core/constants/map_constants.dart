import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 네이버 지도 관련 상수
abstract final class MapConstants {
  /// 물류센터 밀집 지역 중심 (강남·삼성·코엑스 일대)
  static const NLatLng warehouseAreaCenter = NLatLng(37.5128, 127.0471);

  /// 물류센터 5곳이 한눈에 보이는 줌 레벨
  static const double warehouseAreaZoom = 13;

  static const NLatLng defaultCenter = warehouseAreaCenter;
  static const double defaultZoom = warehouseAreaZoom;
}
