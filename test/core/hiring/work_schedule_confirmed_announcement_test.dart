import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 근무예정 합의(양측 확인) 완료 시 — 채팅에 확정 안내가 자동 발송되는지
/// (문자로 면접·근무 일정을 통보하던 관행을 앱 채팅으로 대체).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('instantAccept posts a confirmation chat message', () async {
    final repo = await LocalHiringRepository.create();
    final application = await repo.submitApplication(
      postId: 'post_confirm_1',
      postTitle: '확정안내 테스트 공고',
      companyName: '테스트 기업',
      seekerEmail: 'seeker-confirm-1@test.com',
      seekerName: '테스트',
      seekerPhoneMasked: '010-****',
      workSchedule: '09:00–18:00',
    );

    final scheduled = await repo.instantAccept(
      applicationId: application.id,
      workDate: DateTime(2026, 3, 2),
    );
    expect(scheduled.status, HiringApplicationStatus.scheduled);

    final chatRepo = await ApplicationChatMessageRepository.create();
    final messages = await chatRepo.load(application.id);
    final confirmation = messages.where((m) => m.isSystem && m.text.contains('근무 일정이 확정'));
    expect(confirmation, isNotEmpty);
    final message = confirmation.first;
    expect(message.text, contains('확정안내 테스트 공고'));
    expect(message.text, contains('3월 2일'));
    expect(message.text, contains('09:00–18:00'));
  });

  test(
      'confirmWorkScheduleAgreement posts a confirmation chat message only '
      'once both sides confirm', () async {
    final repo = await LocalHiringRepository.create();
    final application = await repo.submitApplication(
      postId: 'post_confirm_2',
      postTitle: '양측합의 테스트 공고',
      companyName: '테스트 기업',
      seekerEmail: 'seeker-confirm-2@test.com',
      seekerName: '테스트2',
      seekerPhoneMasked: '010-****',
      workSchedule: '10:00–19:00',
    );

    final chatRepo = await ApplicationChatMessageRepository.create();

    await repo.confirmWorkScheduleAgreement(
      applicationId: application.id,
      asEmployer: true,
    );
    final afterFirstConfirm = await chatRepo.load(application.id);
    expect(
      afterFirstConfirm.where((m) => m.text.contains('근무 일정이 확정')),
      isEmpty,
      reason: '한쪽만 확인했을 때는 아직 확정 안내가 나가면 안 됨',
    );

    final updated = await repo.confirmWorkScheduleAgreement(
      applicationId: application.id,
      asEmployer: false,
    );
    expect(updated.status, HiringApplicationStatus.scheduled);

    final afterBothConfirm = await chatRepo.load(application.id);
    expect(
      afterBothConfirm.where((m) => m.text.contains('근무 일정이 확정')),
      isNotEmpty,
    );
  });
}
