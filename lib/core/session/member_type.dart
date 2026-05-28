/// 회원 유형 — 기업(구인) / 개인(구직)
enum MemberType {
  corporate,
  individual,
}

extension MemberTypeX on MemberType {
  String get loginLabel => switch (this) {
        MemberType.corporate => '기업회원 로그인',
        MemberType.individual => '개인회원 로그인',
      };

  String get signUpLabel => switch (this) {
        MemberType.corporate => '기업회원 가입',
        MemberType.individual => '개인회원 가입',
      };

  String get subtitle => switch (this) {
        MemberType.corporate => '일용직·상시직 채용 · 인력 관리',
        MemberType.individual => '지도에서 일자리 찾기 · 지원',
      };

  String get signUpSubtitle => switch (this) {
        MemberType.corporate => '일용직·상시직 공고 등록을 위한 기업 정보를 입력해 주세요',
        MemberType.individual => '일용직·상시직 일자리 매칭을 위한 기본 정보를 입력해 주세요',
      };
}
