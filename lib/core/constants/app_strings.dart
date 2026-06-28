import 'package:map/core/branding/iljari_ad_campaign.dart';
import 'package:map/core/config/product_feature_flags.dart';

/// 앱 전역 문자열 · 플랫폼 포지셔닝
abstract final class AppStrings {
  static const String appName = '일자리';

  static const String searchHint = '지역, 일자리, 근무지 검색';

  static const String createListing = '글쓰기';

  /// 브랜드 광고 카피 (3줄)
  static List<String> get adCampaignLines => IljariAdCampaign.lines;

  static String get adCampaignHeadline => IljariAdCampaign.headline;

  /// 로그인·온보딩
  static String get platformTagline => IljariAdCampaign.headline;

  static String get platformDescription =>
      ProductFeatureFlags.isPermanentHireEnabled
          ? '지도·셔틀·알림으로 내 주변 일자리를 찾고, 장기 근로까지 한곳에서'
          : '물류·식품 현장 — 지도에서 찾고, 집 앞 셔틀 타고 출근';

  static String get loginWelcome => IljariAdCampaign.body;



  /// 수수료 안내 — `ENABLE_HIRING_COMMISSION` / `ENABLE_PERMANENT_HIRE` 활성 빌드 전용
  static const String dailyCommissionNote =
      '일용직(제휴 채널): 출근 확인 시 고정 수수료';

  static const String permanentCommissionNote =
      '상시직(제휴 채널): 건강보험 재직 확인 후 30일마다 월급의 5.5%';

}

