/// 유료 채용 노출·PUSH 상품 종류
enum RecruitmentProductKind {
  /// 일자리 알림핀 또는 정류장 표시핀 — 지도 노출만 (동일 크레딧)
  exposureOnly,

  /// 핀 설치 + 해당 위치 반경 700m PUSH 1회
  exposureWithPush,

  /// 지도 노출 없이 PUSH 발송만
  pushOnly,
}

/// 상점 UI — 노출 상품 표시 구분 (지갑 크레딧은 [RecruitmentProductKind.exposureOnly] 공유)
enum ExposureShopVariant {
  jobPin,
  shuttlePin,
}

extension ExposureShopVariantX on ExposureShopVariant {
  String get productName => switch (this) {
        ExposureShopVariant.jobPin => '일자리 알림핀',
        ExposureShopVariant.shuttlePin => '정류장 표시핀',
      };

  String get shopSubtitle => switch (this) {
        ExposureShopVariant.jobPin =>
          '일자리 알림핀을 지도 상의 번화가, 인구 밀집지역 등에 추가하여 모집 효과를 높일 수 있습니다.',
        ExposureShopVariant.shuttlePin =>
          '운영 중인 통근버스의 정류장과 노선도를 지도 상에 직접 표시하고 연결하여 모집 효과를 높일 수 있습니다.',
      };
}

extension RecruitmentProductKindX on RecruitmentProductKind {
  String get shopSectionTitle => switch (this) {
        RecruitmentProductKind.exposureOnly => '일자리 알림핀·정류장 표시핀',
        RecruitmentProductKind.exposureWithPush => 'PUSH 알림권',
        RecruitmentProductKind.pushOnly => 'PUSH 이용권',
      };

  String get unitLabel => switch (this) {
        RecruitmentProductKind.exposureOnly => '노출 1회',
        RecruitmentProductKind.exposureWithPush => '노출+PUSH 1회',
        RecruitmentProductKind.pushOnly => 'PUSH 1회',
      };
}
