import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/trust/employer_rating.dart';
import 'package:map/core/trust/local_employer_rating_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalEmployerRatingRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('summarizeCompany returns empty when no ratings', () async {
      final repo = await LocalEmployerRatingRepository.create();
      final summary = await repo.summarizeCompany('1234567890');
      expect(summary.reviewCount, 0);
      expect(summary.displayStars, '평가 없음');
    });

    test('save and summarize averages stars', () async {
      final repo = await LocalEmployerRatingRepository.create();
      await repo.save(
        EmployerRating(
          id: 'r1',
          companyKey: '1234567890',
          applicationId: 'app1',
          seekerEmail: 'a@test.com',
          stars: 4,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await repo.save(
        EmployerRating(
          id: 'r2',
          companyKey: '1234567890',
          applicationId: 'app2',
          seekerEmail: 'b@test.com',
          stars: 5,
          createdAt: DateTime(2026, 1, 2),
        ),
      );
      final summary = await repo.summarizeCompany('1234567890');
      expect(summary.reviewCount, 2);
      expect(summary.averageStars, 4.5);
    });

    test('hasRated detects existing application rating', () async {
      final repo = await LocalEmployerRatingRepository.create();
      await repo.save(
        EmployerRating(
          id: 'r1',
          companyKey: '1234567890',
          applicationId: 'app1',
          seekerEmail: 'a@test.com',
          stars: 5,
          createdAt: DateTime.now(),
        ),
      );
      expect(await repo.hasRated('app1'), isTrue);
      expect(await repo.hasRated('app2'), isFalse);
    });
  });
}
