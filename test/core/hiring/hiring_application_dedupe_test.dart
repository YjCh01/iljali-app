import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('mergeServerApplication does not duplicate local apply', () async {
    final repo = await LocalHiringRepository.create();
    const email = 'seeker@test.co.kr';
    const postId = 'post_line_health';

    await repo.ensureSeedApplication(
      HiringApplication(
        id: 'app_local_1',
        postId: postId,
        postTitle: '종합검진 상담 및 예약',
        companyName: '주식회사 라인헬스케어',
        seekerEmail: email,
        seekerName: '최영진',
        seekerPhoneMasked: '010-****-0000',
        appliedAt: DateTime(2026, 6, 28, 10),
        status: HiringApplicationStatus.chatting,
        workSchedule: '09:00~18:00',
      ),
    );

    await repo.mergeServerApplication(
      HiringApplication(
        id: 'app_server_9f3',
        postId: postId,
        postTitle: '종합검진 상담 및 예약',
        companyName: '주식회사 라인헬스케어',
        seekerEmail: email,
        seekerName: '최영진',
        seekerPhoneMasked: '010-0000-0000',
        appliedAt: DateTime(2026, 6, 28, 11),
        status: HiringApplicationStatus.applied,
        workSchedule: '09:00~18:00',
      ),
    );

    final apps = await repo.fetchForSeeker(email);
    expect(apps.length, 1);
    expect(apps.single.id, 'app_server_9f3');
    expect(apps.single.status, HiringApplicationStatus.chatting);
  });

  test('withdraw blocks server merge re-import', () async {
    final repo = await LocalHiringRepository.create();
    const email = 'choi@test.co.kr';
    const postId = 'post_line_health';

    await repo.ensureSeedApplication(
      HiringApplication(
        id: 'app_local',
        postId: postId,
        postTitle: '종합검진',
        companyName: '라인헬스케어',
        seekerEmail: email,
        seekerName: '최영진',
        seekerPhoneMasked: '010-0000-0000',
        appliedAt: DateTime(2026, 6, 30),
        status: HiringApplicationStatus.applied,
        workSchedule: '',
      ),
    );

    await repo.withdrawBySeeker(postId: postId, seekerEmail: email);

    await repo.mergeServerApplication(
      HiringApplication(
        id: 'app_server_stale',
        postId: postId,
        postTitle: '종합검진',
        companyName: '라인헬스케어',
        seekerEmail: email,
        seekerName: '최영진',
        seekerPhoneMasked: '010-0000-0000',
        appliedAt: DateTime(2026, 6, 30, 12),
        status: HiringApplicationStatus.applied,
        workSchedule: '',
      ),
    );

    final apps = await repo.fetchForSeeker(email);
    expect(apps.where((a) => a.postId == postId), isEmpty);
  });

  test('dedupeActiveApplicationsForSeeker keeps chatting over applied', () async {
    final repo = await LocalHiringRepository.create();
    const email = 'seeker@test.co.kr';

    await repo.ensureSeedApplication(
      HiringApplication(
        id: 'app_old',
        postId: 'post_dup',
        postTitle: '공고',
        companyName: '기업',
        seekerEmail: email,
        seekerName: '테스트',
        seekerPhoneMasked: '010-0000-0000',
        appliedAt: DateTime(2026, 6, 27),
        status: HiringApplicationStatus.applied,
        workSchedule: '',
      ),
    );
    await repo.ensureSeedApplication(
      HiringApplication(
        id: 'app_new',
        postId: 'post_dup',
        postTitle: '공고',
        companyName: '기업',
        seekerEmail: email,
        seekerName: '테스트',
        seekerPhoneMasked: '010-0000-0000',
        appliedAt: DateTime(2026, 6, 28),
        status: HiringApplicationStatus.chatting,
        workSchedule: '',
      ),
    );

    final apps = await repo.fetchForSeeker(email);
    expect(apps.length, 1);
    expect(apps.single.id, 'app_new');
  });
}
