import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';

void main() {
  group('JobPostDescriptionBody', () {
    test('hasContent detects text, html, and images', () {
      expect(const JobPostDescriptionBody().hasContent, isFalse);
      expect(
        const JobPostDescriptionBody(text: '안내').hasContent,
        isTrue,
      );
      expect(
        const JobPostDescriptionBody(html: '<p>안내</p>').hasContent,
        isTrue,
      );
      expect(
        const JobPostDescriptionBody(imageUrls: ['https://x/a.jpg']).hasContent,
        isTrue,
      );
    });

    test('calloutSnippet is empty for image-only body', () {
      expect(
        const JobPostDescriptionBody(
          imageUrls: ['https://x/a.jpg'],
        ).calloutSnippet,
        isEmpty,
      );
    });

    test('round-trips JSON', () {
      const body = JobPostDescriptionBody(
        text: '본문',
        html: '<p>HTML</p>',
        imageUrls: ['https://cdn/a.jpg'],
      );
      final restored = JobPostDescriptionBody.fromJson(body.toJson());
      expect(restored.text, body.text);
      expect(restored.html, body.html);
      expect(restored.imageUrls, body.imageUrls);
    });
  });
}
