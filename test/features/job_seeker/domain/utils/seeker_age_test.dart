import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_age.dart';

void main() {
  group('SeekerAge', () {
    test('internationalAge before birthday', () {
      final age = SeekerAge.internationalAge(
        DateTime(1990, 6, 15),
        reference: DateTime(2026, 6, 14),
      );
      expect(age, 35);
    });

    test('internationalAge on birthday', () {
      final age = SeekerAge.internationalAge(
        DateTime(1990, 6, 15),
        reference: DateTime(2026, 6, 15),
      );
      expect(age, 36);
    });

    test('formatLabel returns 만 N세', () {
      expect(
        SeekerAge.formatLabel(
          DateTime(1990, 1, 1),
          reference: DateTime(2026, 6, 19),
        ),
        '만 36세',
      );
    });
  });
}
