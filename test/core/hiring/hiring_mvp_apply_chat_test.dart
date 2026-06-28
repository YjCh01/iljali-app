import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/core/session/member_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MVP 채용 — 공고·지원·채팅만 (근무예정 합의·출근·수수료 없음)
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  test('seeker apply then chat without work-agreement actions', () async {
    const seeker = DevTestAccounts.seekerAlpha;
    final hiringRepo = await LocalHiringRepository.create();

    await AuthSession.instance.signIn(seeker.toAuthUser());

    final application = await hiringRepo.submitApplication(
      postId: 'post_mvp_chat',
      postTitle: 'MVP 채팅 테스트',
      companyName: '테스트 기업',
      companyKey: 'corp_mvp',
      seekerEmail: seeker.email,
      seekerName: seeker.displayName,
      seekerPhoneMasked: '010-****-0001',
      workSchedule: '09:00~18:00',
    );
    expect(application.status, HiringApplicationStatus.applied);

    final policy = ChatAccessPolicy.evaluatePair(
      requester: MemberType.individual,
      peer: MemberType.corporate,
    );
    expect(policy.allowed, isTrue);

    await hiringRepo.startChat(application.id);
    final chatting = await hiringRepo.findById(application.id);
    expect(chatting?.status, HiringApplicationStatus.chatting);

    expect(
      () => hiringRepo.confirmWorkScheduleAgreement(
        applicationId: application.id,
        asEmployer: false,
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      () => hiringRepo.instantAccept(applicationId: application.id),
      throwsA(isA<StateError>()),
    );

    final overdue =
        await hiringRepo.fetchOverdueUncheckedShifts(seeker.email);
    expect(overdue, isEmpty);
  });
}
