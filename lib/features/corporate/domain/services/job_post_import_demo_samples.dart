/// MVP 데모용 공고 가져오기 샘플 (영업·QA)
abstract final class JobPostImportDemoSamples {
  static const demoUrl = 'https://www.albamon.com/job/demo-picking-12345';

  static const albamonText = '''
물류센터 피킹·포장 보조 모집
시급 : 12,000원
근무시간 : 09:00 ~ 18:00 (주5일)
근무지 : 경기도 화성시 동탄대로 123
모집내용
- 입출고 보조, 박스 포장
- 성실하고 체력이 좋으신 분
''';

  static const mvpHintSteps = '''
① 「데모 채우기」로 샘플 붙여넣기
② 「텍스트 분석」 또는 「링크 불러오기」
③ 미리보기 확인 → 「가져온 내용으로 등록하기」
※ 서버 없이도 데모 URL·텍스트로 동작합니다
''';
}
