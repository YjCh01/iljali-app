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
}
