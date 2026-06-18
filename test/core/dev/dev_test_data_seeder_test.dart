import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/dev_test_data_seeder.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/datasources/job_map_pins_data_source.dart';
import 'package:map/features/job_seeker/domain/usecases/get_job_map_pins_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
  });

  test('ensureSeeded creates map-visible test job posts', () async {
    await DevTestDataSeeder.ensureSeeded();

    const posts = CorporateJobPostLocalDataSourceImpl();
    final alpha = await posts.findById('test_post_corp_alpha_warehouse');
    final beta = await posts.findById('test_post_corp_beta_kitchen');
    expect(alpha, isNotNull);
    expect(beta, isNotNull);
    expect(alpha!.status, CorporateJobPostStatus.recruiting);
    expect(beta!.status, CorporateJobPostStatus.recruiting);

    final pins = await const GetJobMapPinsUseCase(
      JobMapPinsLocalDataSource(jobPosts: posts),
    ).call();
    expect(
      pins.any((pin) => pin.post.id == alpha.id),
      isTrue,
      reason: 'seeded alpha post should appear on map',
    );
    expect(
      pins.any((pin) => pin.post.id == beta.id),
      isTrue,
      reason: 'seeded beta post should appear on map',
    );
  });

  test('ensureSeeded is idempotent for job posts', () async {
    await DevTestDataSeeder.ensureSeeded();
    await DevTestDataSeeder.ensureSeeded();
    final all = await const CorporateJobPostLocalDataSourceImpl().fetchJobPosts();
    expect(
      all.where((p) => p.id.startsWith('test_post_')).length,
      2,
    );
  });
}
