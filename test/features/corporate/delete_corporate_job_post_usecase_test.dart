import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/usecases/delete_corporate_job_post_usecase.dart';

void main() {
  tearDown(() {
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
  });

  test('delete removes post from local store', () async {
    const dataSource = CorporateJobPostLocalDataSourceImpl();
    final post = CorporateJobPost(
      id: 'post_delete_test',
      title: '삭제 테스트',
      warehouseName: '평택',
      hourlyWage: '10,000원',
      workSchedule: '주 5일',
      summary: '요약',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: DateTime(2026, 1, 1),
    );
    await dataSource.createJobPost(post);

    final result = await const DeleteCorporateJobPostUseCase(dataSource).call(
      postId: post.id,
    );

    expect(result.deletedLocally, isTrue);
    expect(await dataSource.findById(post.id), isNull);
    if (!EnvConfig.isComplianceApiEnabled) {
      expect(result.syncedToServer, isTrue);
    }
  });
}
