import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 면접 제안 → 상호 확인 흐름 — 근무예정 합의와 별개의 독립적인 플로우.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('proposeInterview records the interview time and employer agreement', () async {
    final repo = await LocalHiringRepository.create();
    final application = await repo.submitApplication(
      postId: 'post_interview_1',
      postTitle: '면접 테스트 공고',
      companyName: '테스트 기업',
      seekerEmail: 'seeker-interview-1@test.com',
      seekerName: '지원자',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );

    final interviewAt = DateTime(2026, 3, 5, 14, 0);
    final proposed = await repo.proposeInterview(
      applicationId: application.id,
      interviewAt: interviewAt,
    );

    expect(proposed.interviewAt, interviewAt);
    expect(proposed.employerInterviewAgreedAt, isNotNull);
    expect(proposed.seekerInterviewAgreedAt, isNull);
    expect(proposed.isInterviewAgreementComplete, isFalse);

    final chatRepo = await ApplicationChatMessageRepository.create();
    final messages = await chatRepo.load(application.id);
    expect(messages.where((m) => m.text.contains('면접 제안')), isNotEmpty);
  });

  test(
      'confirmInterviewAgreement completes only once both sides confirm, '
      'and posts a confirmation chat message', () async {
    final repo = await LocalHiringRepository.create();
    final application = await repo.submitApplication(
      postId: 'post_interview_2',
      postTitle: '면접 확정 테스트 공고',
      companyName: '테스트 기업',
      seekerEmail: 'seeker-interview-2@test.com',
      seekerName: '지원자2',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );

    final interviewAt = DateTime(2026, 3, 6, 10, 30);
    await repo.proposeInterview(
      applicationId: application.id,
      interviewAt: interviewAt,
    );

    final chatRepo = await ApplicationChatMessageRepository.create();
    final beforeSeekerConfirm = await chatRepo.load(application.id);
    expect(
      beforeSeekerConfirm.where((m) => m.text.contains('면접 일정이 확정')),
      isEmpty,
      reason: '구직자가 아직 확인하지 않았으면 확정 안내가 나가면 안 됨',
    );

    final updated = await repo.confirmInterviewAgreement(
      applicationId: application.id,
      asEmployer: false,
    );

    expect(updated.isInterviewAgreementComplete, isTrue);

    final afterConfirm = await chatRepo.load(application.id);
    expect(
      afterConfirm.where((m) => m.text.contains('면접 일정이 확정')),
      isNotEmpty,
    );
  });

  test('confirmInterviewAgreement throws when no interview was proposed', () async {
    final repo = await LocalHiringRepository.create();
    final application = await repo.submitApplication(
      postId: 'post_interview_3',
      postTitle: '면접 없음 테스트 공고',
      companyName: '테스트 기업',
      seekerEmail: 'seeker-interview-3@test.com',
      seekerName: '지원자3',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );

    expect(
      () => repo.confirmInterviewAgreement(
        applicationId: application.id,
        asEmployer: false,
      ),
      throwsStateError,
    );
  });

  test('proposeInterview a second time resets seeker agreement', () async {
    final repo = await LocalHiringRepository.create();
    final application = await repo.submitApplication(
      postId: 'post_interview_4',
      postTitle: '면접 재제안 테스트 공고',
      companyName: '테스트 기업',
      seekerEmail: 'seeker-interview-4@test.com',
      seekerName: '지원자4',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );

    await repo.proposeInterview(
      applicationId: application.id,
      interviewAt: DateTime(2026, 3, 7, 13, 0),
    );
    await repo.confirmInterviewAgreement(
      applicationId: application.id,
      asEmployer: false,
    );

    final rescheduled = await repo.proposeInterview(
      applicationId: application.id,
      interviewAt: DateTime(2026, 3, 8, 15, 0),
    );

    expect(rescheduled.interviewAt, DateTime(2026, 3, 8, 15, 0));
    expect(rescheduled.seekerInterviewAgreedAt, isNull);
    expect(rescheduled.isInterviewAgreementComplete, isFalse);
  });
}
