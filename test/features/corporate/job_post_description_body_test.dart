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

    test('fromMap extracts images from html when images field empty', () {
      final body = JobPostDescriptionBody.fromMap({
        'html':
            '<p><img src="https://file.albamon.com/a.jpg" /></p>'
            '<p><img src="https://file.albamon.com/b.png" /></p>',
      });
      expect(body.imageUrls, [
        'https://file.albamon.com/a.jpg',
        'https://file.albamon.com/b.png',
      ]);
    });
  });
}
