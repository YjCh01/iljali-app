import 'dart:typed_data';

import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';

/// 공고 캡처 OCR (MVP mock — 실서비스 시 CLOVA OCR·서버 프록시)
class MockJobPostScreenshotOcrService {
  const MockJobPostScreenshotOcrService();

  Future<String> extractText({
    required Uint8List imageBytes,
    required String fileName,
    ExternalJobPostPlatform platform = ExternalJobPostPlatform.unknown,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (imageBytes.isEmpty) {
      throw ArgumentError('이미지를 읽을 수 없습니다.');
    }

    return switch (platform) {
      ExternalJobPostPlatform.albamon => '''
[알바몬 캡처 인식]
물류센터 피킹 보조
시급 : 12,000원
09:00 ~ 18:00 (주5일)
경기도 화성시 동탄대로 123
입출고·포장 보조
''',
      ExternalJobPostPlatform.karrot => '''
당근알바
물류 보조 알바
시급 12000원
09:00-18:00
화성 동탄
''',
      _ => '''
[캡처 인식]
현장 보조 알바 모집
시급 12,000원
09:00-18:00
경기도 화성시 동탄대로 123
단순 보조 업무
''',
    };
  }
}
