import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/chat_message_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('chat messages persist across reload', () async {
    final repo = await ApplicationChatMessageRepository.create();
    const appId = 'chat_persist_test';

    await repo.ensureWelcomeMessages(
      applicationId: appId,
      companyName: '테스트기업',
      postTitle: '테스트 공고',
      seekerName: '홍길동',
    );
    await repo.append(
      appId,
      ApplicationChatMessage(
        fromEmployer: false,
        text: '내일 몇 시에 출근하면 될까요?',
        sentAt: DateTime.now(),
      ),
    );

    final first = await repo.load(appId);
    expect(first.length, 3);

    final reloaded = await ApplicationChatMessageRepository.create();
    final second = await reloaded.load(appId);
    expect(second.length, 3);
    expect(second.last.text, '내일 몇 시에 출근하면 될까요?');
  });

  test('attachment messages serialize with kind and path', () {
    final message = ApplicationChatMessage(
      fromEmployer: false,
      text: '통장사본을 보냈습니다.',
      sentAt: DateTime(2026, 5, 27, 10),
      kind: ChatMessageKind.bankAccount,
      attachmentPath: '/tmp/bank.jpg',
    );

    final json = message.toJson();
    final restored = ApplicationChatMessage.fromJson(json);

    expect(restored.kind, ChatMessageKind.bankAccount);
    expect(restored.attachmentPath, '/tmp/bank.jpg');
  });

  test('viewport contains only pins in visible bounds', () {
    final viewport = MapViewportBounds.fromCenter(
      centerLat: 37.4,
      centerLng: 127.1,
      latSpan: 0.02,
      lngSpan: 0.02,
    );

    expect(viewport.contains(latitude: 37.4, longitude: 127.1), isTrue);
    expect(viewport.contains(latitude: 37.9, longitude: 127.9), isFalse);
  });
}
