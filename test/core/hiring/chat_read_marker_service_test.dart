import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/chat_read_marker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ApplicationChatMessage message({
    required bool fromEmployer,
    required DateTime sentAt,
  }) =>
      ApplicationChatMessage(
        fromEmployer: fromEmployer,
        text: 'hi',
        sentAt: sentAt,
      );

  test('all counterparty messages are unread before any markRead call',
      () async {
    final messages = [
      message(fromEmployer: true, sentAt: DateTime(2026, 1, 1, 9)),
      message(fromEmployer: true, sentAt: DateTime(2026, 1, 1, 10)),
      message(fromEmployer: false, sentAt: DateTime(2026, 1, 1, 11)),
    ];

    final unread = await ChatReadMarkerService.unreadCount(
      applicationId: 'app_1',
      asEmployer: false,
      messages: messages,
      userEmail: 'seeker@test.com',
    );
    // 구직자 입장에서 상대(기업)가 보낸 메시지만 카운트.
    expect(unread, 2);
  });

  test('markRead resets unread count for messages sent before the mark',
      () async {
    final messages = [
      message(fromEmployer: true, sentAt: DateTime.now()),
    ];

    await ChatReadMarkerService.markRead(
      applicationId: 'app_2',
      userEmail: 'seeker@test.com',
    );
    final unread = await ChatReadMarkerService.unreadCount(
      applicationId: 'app_2',
      asEmployer: false,
      messages: messages,
      userEmail: 'seeker@test.com',
    );
    expect(unread, 0);
  });

  test('new counterparty message after markRead counts as unread again',
      () async {
    await ChatReadMarkerService.markRead(
      applicationId: 'app_3',
      userEmail: 'employer@test.com',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final messages = [
      message(fromEmployer: false, sentAt: DateTime.now()),
    ];

    final unread = await ChatReadMarkerService.unreadCount(
      applicationId: 'app_3',
      asEmployer: true,
      messages: messages,
      userEmail: 'employer@test.com',
    );
    expect(unread, 1);
  });

  test('own messages never count as unread', () async {
    final messages = [
      message(fromEmployer: true, sentAt: DateTime.now()),
    ];
    final unread = await ChatReadMarkerService.unreadCount(
      applicationId: 'app_4',
      asEmployer: true,
      messages: messages,
      userEmail: 'employer@test.com',
    );
    expect(unread, 0);
  });

  test('unread counts are isolated per applicationId and per user', () async {
    await ChatReadMarkerService.markRead(
      applicationId: 'app_5',
      userEmail: 'seeker@test.com',
    );
    final messages = [
      message(fromEmployer: true, sentAt: DateTime.now()),
    ];

    final unreadOtherApp = await ChatReadMarkerService.unreadCount(
      applicationId: 'app_6',
      asEmployer: false,
      messages: messages,
      userEmail: 'seeker@test.com',
    );
    expect(unreadOtherApp, 1);

    final unreadOtherUser = await ChatReadMarkerService.unreadCount(
      applicationId: 'app_5',
      asEmployer: false,
      messages: messages,
      userEmail: 'other-seeker@test.com',
    );
    expect(unreadOtherUser, 1);
  });
}
