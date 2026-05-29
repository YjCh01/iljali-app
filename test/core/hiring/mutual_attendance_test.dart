import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/seeker_attendance_gate_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LocalHiringRepository> repo() => LocalHiringRepository.create();

  Future<String> seedScheduled({
    required LocalHiringRepository repository,
    String email = 'seeker@test.com',
    DateTime? workDate,
  }) async {
    final app = await repository.submitApplication(
      postId: 'post_${DateTime.now().microsecondsSinceEpoch}',
      postTitle: '일용 모집',
      companyName: '(주)일자리',
      seekerEmail: email,
      seekerName: '테스트',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
      employmentType: JobEmploymentType.daily,
      hourlyWageText: '12000',
    );
    final scheduled = await repository.instantAccept(
      applicationId: app.id,
      workDate: workDate ?? DateTime(2020, 1, 1),
    );
    return scheduled.id;
  }

  test('seeker check-in only is not commission eligible', () async {
    final repository = await repo();
    final id = await seedScheduled(repository: repository);

    final checkedIn = await repository.checkIn(id);
    expect(checkedIn.seekerCheckedIn, isTrue);
    expect(checkedIn.employerConfirmed, isFalse);
    expect(checkedIn.isMutuallyConfirmed, isFalse);
    expect(checkedIn.status, HiringApplicationStatus.scheduled);
    expect(checkedIn.needsCommissionPayment, isFalse);

    expect(
      () => repository.markCommissionPaid(id),
      throwsA(isA<StateError>()),
    );
  });

  test('mutual confirm after seeker then employer enables commission', () async {
    final repository = await repo();
    final id = await seedScheduled(repository: repository);

    await repository.checkIn(id);
    final mutual = await repository.confirmEmployerAttendance(id);

    expect(mutual.isMutuallyConfirmed, isTrue);
    expect(mutual.status, HiringApplicationStatus.checkedIn);
    expect(mutual.needsCommissionPayment, isTrue);

    final paid = await repository.markCommissionPaid(id);
    expect(paid.status, HiringApplicationStatus.commissionPaid);
    expect(paid.commissionPaidAt, isNotNull);
  });

  test('mutual confirm after employer then seeker enables commission', () async {
    final repository = await repo();
    final id = await seedScheduled(repository: repository);

    await repository.confirmEmployerAttendance(id);
    final mutual = await repository.checkIn(id);

    expect(mutual.isMutuallyConfirmed, isTrue);
    expect(mutual.needsCommissionPayment, isTrue);
  });

  test('auto-confirms employer after 48h silence', () async {
    final repository = await repo();
    final id = await seedScheduled(repository: repository);

    final checkedIn = await repository.checkIn(id);
    final stale = checkedIn.copyWith(
      checkedInAt: DateTime.now().subtract(const Duration(hours: 49)),
    );
    SharedPreferences.setMockInitialValues({
      'hiring_applications_v1': jsonEncode([stale.toJson()]),
    });
    final patchedRepo = await repo();

    final autoConfirmed = await patchedRepo.autoConfirmSilentEmployers();
    expect(autoConfirmed, hasLength(1));
    expect(autoConfirmed.first.isMutuallyConfirmed, isTrue);
    expect(autoConfirmed.first.needsCommissionPayment, isTrue);
  });

  test('seeker gate allows one overdue missed shift', () async {
    final repository = await repo();
    await seedScheduled(
      repository: repository,
      email: 'late@test.com',
      workDate: DateTime(2020, 1, 1),
    );

    final gate = await SeekerAttendanceGateService(repository: repository)
        .evaluate('late@test.com');
    expect(gate.isLocked, isFalse);
    expect(gate.overdueCount, 1);
  });

  test('seeker gate locks after two overdue missed shifts', () async {
    final repository = await repo();
    await seedScheduled(
      repository: repository,
      email: 'late2@test.com',
      workDate: DateTime(2020, 1, 1),
    );
    await seedScheduled(
      repository: repository,
      email: 'late2@test.com',
      workDate: DateTime(2020, 1, 2),
    );

    final gate = await SeekerAttendanceGateService(repository: repository)
        .evaluate('late2@test.com');
    expect(gate.isLocked, isTrue);
    expect(gate.overdueCount, 2);
    expect(gate.message, contains('미확인 출근'));
  });
}
