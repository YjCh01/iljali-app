import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/seeker_no_show_blacklist_service.dart';
import 'package:map/core/hiring/work_schedule_time.dart';
import 'package:map/features/corporate/data/datasources/corporate_attendance_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var seedCounter = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    seedCounter = 0;
  });

  Future<LocalHiringRepository> repo() => LocalHiringRepository.create();

  Future<HiringApplication> seedApplication({
    required LocalHiringRepository repository,
    String email = 'seeker@test.com',
    DateTime? workDate,
    bool agreementComplete = true,
  }) async {
    seedCounter++;
    final app = await repository.submitApplication(
      postId: 'post_$seedCounter',
      postTitle: '일용 모집 $seedCounter',
      companyName: '(주)일자리',
      seekerEmail: email,
      seekerName: '테스트',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
      employmentType: JobEmploymentType.daily,
      hourlyWageText: '12000',
    );
    var updated = app;
    if (agreementComplete) {
      updated = await repository.confirmWorkScheduleAgreement(
        applicationId: app.id,
        asEmployer: true,
      );
      updated = await repository.confirmWorkScheduleAgreement(
        applicationId: app.id,
        asEmployer: false,
      );
    }
    if (updated.status != HiringApplicationStatus.scheduled) {
      updated = await repository.instantAccept(
        applicationId: updated.id,
        workDate: workDate ?? DateTime(2020, 1, 1),
      );
    }
    return updated;
  }

  test('markNoShowByEmployer requires agreement and scheduled status', () async {
    final repository = await repo();
    final incomplete = await repository.submitApplication(
      postId: 'post_incomplete',
      postTitle: '미합의',
      companyName: '(주)일자리',
      seekerEmail: 'seeker@test.com',
      seekerName: '테스트',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );
    await _saveApplication(
      incomplete.copyWith(
        status: HiringApplicationStatus.scheduled,
        workDate: DateTime(2020, 1, 1),
      ),
    );

    expect(
      () => repository.markNoShowByEmployer(incomplete.id),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'agreement_incomplete')),
    );

    final scheduled = await seedApplication(repository: repository);
    final noShow = await repository.markNoShowByEmployer(scheduled.id);
    expect(noShow.status, HiringApplicationStatus.noShow);
    expect(noShow.noShowMarkedAt, isNotNull);
  });

  test('markNoShowByEmployer rejects mutually confirmed shifts', () async {
    final repository = await repo();
    final scheduled = await seedApplication(repository: repository);
    await repository.checkIn(scheduled.id);
    await repository.confirmEmployerAttendance(scheduled.id);

    expect(
      () => repository.markNoShowByEmployer(scheduled.id),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'not_scheduled')),
    );
  });

  test('consecutiveNoShowCount blacklists after 3 streak', () async {
    final repository = await repo();
    final blacklist = SeekerNoShowBlacklistService(
      await SharedPreferences.getInstance(),
    );
    const email = 'streak@test.com';

    for (var i = 0; i < 3; i++) {
      final app = await seedApplication(
        repository: repository,
        email: email,
        workDate: DateTime(2020, 1, 10 - i),
      );
      await repository.markNoShowByEmployer(app.id);
      await blacklist.recordEmployerNoShow(
        seekerEmail: email,
        hiringRepo: repository,
      );
    }

    expect(await blacklist.isBlacklisted(email), isTrue);
    expect(
      await blacklist.consecutiveNoShowCount(email, repository),
      3,
    );
  });

  test('agreement-cancelled shifts are excluded from no-show streak', () async {
    final repository = await repo();
    const email = 'cancel@test.com';

    final cancelled = await seedApplication(
      repository: repository,
      email: email,
      workDate: DateTime(2020, 1, 5),
    );
    await _saveApplication(
      cancelled.copyWith(
        status: HiringApplicationStatus.noShow,
        noShowMarkedAt: DateTime.now(),
        agreementCancelledAt: DateTime.now(),
      ),
    );

    final counted = await seedApplication(
      repository: repository,
      email: email,
      workDate: DateTime(2020, 1, 4),
    );
    await repository.markNoShowByEmployer(counted.id);

    final blacklist = SeekerNoShowBlacklistService(
      await SharedPreferences.getInstance(),
    );
    expect(await blacklist.consecutiveNoShowCount(email, repository), 1);
  });

  test('corporate attendance lists only work-agreement-complete records',
      () async {
    final repository = await repo();
    await repository.submitApplication(
      postId: 'post_no_agreement',
      postTitle: '미합의 공고',
      companyName: '(주)일자리',
      seekerEmail: 'other@test.com',
      seekerName: '미합의',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );
    await seedApplication(
      repository: repository,
      email: 'agreed@test.com',
    );

    final records =
        await const CorporateAttendanceLocalDataSourceImpl().fetchRecords();
    expect(records, hasLength(1));
    expect(records.single.workAgreementComplete, isTrue);
    expect(records.single.workerName, '테스트');
  });

  test('canMarkNoShow is false before work start time', () async {
    await seedApplication(
      repository: await repo(),
      workDate: DateTime.now().add(const Duration(days: 1)),
    );

    final records =
        await const CorporateAttendanceLocalDataSourceImpl().fetchRecords();
    expect(records.single.canMarkNoShow, isFalse);
    expect(
      WorkScheduleTime.workStartAt(
        DateTime.now().add(const Duration(days: 1)),
        '09:00–18:00',
      ),
      isNotNull,
    );
  });

  test('blacklisted seeker map browse quota is 3 per day', () async {
    const email = 'browse@test.com';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seeker_blacklist_${email.toLowerCase()}', true);
    final blacklist = SeekerNoShowBlacklistService(prefs);

    expect(await blacklist.remainingMapBrowsesToday(email), 3);
    expect(await blacklist.consumeMapBrowse(email), isTrue);
    expect(await blacklist.consumeMapBrowse(email), isTrue);
    expect(await blacklist.consumeMapBrowse(email), isTrue);
    expect(await blacklist.consumeMapBrowse(email), isFalse);
    expect(await blacklist.remainingMapBrowsesToday(email), 0);
  });
}

Future<void> _saveApplication(HiringApplication application) async {
  final repository = await LocalHiringRepository.create();
  final all = await repository.fetchAll();
  final index = all.indexWhere((item) => item.id == application.id);
  if (index >= 0) {
    all[index] = application;
  } else {
    all.insert(0, application);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'hiring_applications_v1',
    jsonEncode(all.map((item) => item.toJson()).toList()),
  );
}
