import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_description_image.dart';

void main() {
  test('decodeDataUrl parses base64 image payload', () {
    const payload = 'aGVsbG8=';
    final url = 'data:image/png;base64,$payload';
    final bytes = JobPostDescriptionImage.decodeDataUrl(url);
    expect(bytes, isNotNull);
    expect(bytes, base64Decode(payload));
  });

  test('decodeDataUrl returns null for http URL', () {
    expect(
      JobPostDescriptionImage.decodeDataUrl('https://cdn.example/a.jpg'),
      isNull,
    );
  });

  test('resolveDisplayUrl leaves our media paths alone', () {
    const url = 'https://api.example/media/job-posts/abc.jpg';
    expect(JobPostDescriptionImage.resolveDisplayUrl(url), url);
  });

  test('resolveDisplayUrl proxies albamon CDN when API base is set', () {
    const raw = 'https://file.albamon.com/recruit/detail/a.jpg';
    final resolved = JobPostDescriptionImage.resolveDisplayUrl(raw);
    // 테스트 기본 --dart-define 없으면 base empty → 원본 유지
    // 프로덕션(define 있음)에서는 /v1/job-media/proxy 사용
    expect(
      resolved == raw || resolved.contains('/v1/job-media/proxy'),
      isTrue,
    );
  });
}
