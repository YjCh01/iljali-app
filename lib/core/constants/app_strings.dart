import 'package:map/core/config/product_feature_flags.dart';



/// 앱 전역 문자열 · 플랫폼 포지셔닝

abstract final class AppStrings {

  static const String appName = '일자리';

  static const String searchHint = '지역, 일자리, 근무지 검색';

  static const String createListing = '글쓰기';



  /// 로그인·온보딩

  static String get platformTagline =>

      ProductFeatureFlags.isPermanentHireEnabled

          ? '일용직·상시직, 한곳에서 매칭'

          : '일용직 현장 채용, 한곳에서 매칭';



  static String get platformDescription =>

      ProductFeatureFlags.isPermanentHireEnabled

          ? '즉시 출근 매칭부터 장기 근로자 관리까지 — 종합 일자리 플랫폼'

          : '물류·식품 공장 일용직 매칭 — 현장 채용에 집중';



  static String get loginWelcome =>

      ProductFeatureFlags.isPermanentHireEnabled

          ? '일용직부터 상시직까지, 종합 일자리 플랫폼에 오신 것을 환영합니다'

          : '일용직 현장 채용 플랫폼에 오신 것을 환영합니다';



  /// 수수료 안내

  static const String dailyCommissionNote =

      '일용직: 출근 확인 시 고정 수수료';

  static const String permanentCommissionNote =

      '상시직: 건강보험 재직 확인 후 30일마다 월급의 5.5%';

}

