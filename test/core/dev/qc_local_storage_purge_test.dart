import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/qc_local_storage_purge.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_pin.dart';

void main() {
  test('detects QC company, post, email, ghost pin', () {
    expect(QcLocalStoragePurge.isQcCompanyKey('1000000001'), isTrue);
    expect(QcLocalStoragePurge.isQcPostId('qc_post_real_001'), isTrue);
    expect(
      QcLocalStoragePurge.isQcEmail('seeker-0001@qc.iljari.co.kr'),
      isTrue,
    );
    expect(
      QcLocalStoragePurge.isQcGhostPin(
        const ClosedGhostPin(
          id: 'ghost_qc_1',
          latitude: 37.5,
          longitude: 127.0,
        ),
      ),
      isTrue,
    );
    expect(
      QcLocalStoragePurge.isQcJobPost(
        CorporateJobPost(
          id: 'qc_post_real_001',
          title: 't',
          warehouseName: 'w',
          hourlyWage: '1',
          workSchedule: 's',
          summary: 's',
          status: CorporateJobPostStatus.recruiting,
          applicantCount: 0,
          postedAt: DateTime(2026, 1, 1),
        ),
      ),
      isTrue,
    );
  });
}
