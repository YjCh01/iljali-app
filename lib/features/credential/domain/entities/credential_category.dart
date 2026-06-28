/// 법정·현장 필수 자격 카테고리
enum CredentialCategory {
  constructionManufacturing,
  logisticsDriving,
  facilitySecurity,
  cleaningCare,
}

extension CredentialCategoryX on CredentialCategory {
  String get label => switch (this) {
        CredentialCategory.constructionManufacturing =>
          '건설 및 제조·중장비 현장',
        CredentialCategory.logisticsDriving => '물류 및 유통·운전',
        CredentialCategory.facilitySecurity => '시설관리(전기·소방·영선) 및 경비',
        CredentialCategory.cleaningCare => '미화 및 요양·돌봄',
      };

  String get id => name;
}
