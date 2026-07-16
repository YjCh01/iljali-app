import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/navigation/global_navigator.dart';
import 'package:map/core/notifications/push_incoming_handler.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ),
    );
  }

  testWidgets(
    'tapping a chat_message push opens the application chat page',
    (tester) async {
      await pumpApp(tester);

      await PushIncomingHandler.handleOpenedApp(
        const RemoteMessage(
          data: {'type': 'chat_message', 'application_id': 'app_123'},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ApplicationChatPage), findsOneWidget);
    },
  );

  testWidgets(
    'a chat_message push with no application_id does not navigate',
    (tester) async {
      await pumpApp(tester);

      await PushIncomingHandler.handleOpenedApp(
        const RemoteMessage(data: {'type': 'chat_message'}),
      );
      await tester.pump();

      expect(find.byType(ApplicationChatPage), findsNothing);
    },
  );

  testWidgets(
    'non chat_message pushes do not navigate to the chat page',
    (tester) async {
      await pumpApp(tester);

      await PushIncomingHandler.handleOpenedApp(
        const RemoteMessage(
          data: {'type': 'job_recruitment', 'post_id': 'post_1'},
        ),
      );
      await tester.pump();

      expect(find.byType(ApplicationChatPage), findsNothing);
      expect(find.text('home'), findsOneWidget);
    },
  );
}
