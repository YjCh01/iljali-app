import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/navigation/global_navigator.dart';
import 'package:map/core/notifications/push_incoming_handler.dart';
import 'package:map/features/corporate/domain/services/corporate_new_applicant_signal.dart';
import 'package:map/features/corporate/presentation/pages/corporate_applicant_resume_page.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/job_seeker/domain/services/seeker_application_update_signal.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
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
    'tapping a new_applicant push opens the applicant resume page',
    (tester) async {
      await pumpApp(tester);

      await PushIncomingHandler.handleOpenedApp(
        const RemoteMessage(
          data: {'type': 'new_applicant', 'application_id': 'app_456'},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CorporateApplicantResumePage), findsOneWidget);
    },
  );

  testWidgets(
    'a foreground new_applicant push bumps the badge signal and shows a snackbar',
    (tester) async {
      await pumpApp(tester);
      final before = CorporateNewApplicantSignal.ping.value;

      await PushIncomingHandler.handleForeground(
        const RemoteMessage(
          data: {'type': 'new_applicant', 'application_id': 'app_789'},
          notification: RemoteNotification(
            title: '새 지원자가 도착했습니다',
            body: '홍길동님이 「창고 피킹」에 지원했습니다.',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(CorporateNewApplicantSignal.ping.value, before + 1);
      expect(find.text('홍길동님이 「창고 피킹」에 지원했습니다.'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CorporateApplicantResumePage), findsOneWidget);
    },
  );

  testWidgets(
    'a foreground push for a different type does not bump the applicant signal',
    (tester) async {
      await pumpApp(tester);
      final before = CorporateNewApplicantSignal.ping.value;

      await PushIncomingHandler.handleForeground(
        const RemoteMessage(data: {'type': 'chat_message'}),
      );
      await tester.pump();

      expect(CorporateNewApplicantSignal.ping.value, before);
    },
  );

  testWidgets(
    'tapping a work_schedule_confirmed push opens the application chat page',
    (tester) async {
      await pumpApp(tester);

      await PushIncomingHandler.handleOpenedApp(
        const RemoteMessage(
          data: {
            'type': 'work_schedule_confirmed',
            'application_id': 'app_work_1',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ApplicationChatPage), findsOneWidget);
    },
  );

  testWidgets(
    'tapping an interview_confirmed push opens the application chat page',
    (tester) async {
      await pumpApp(tester);

      await PushIncomingHandler.handleOpenedApp(
        const RemoteMessage(
          data: {
            'type': 'interview_confirmed',
            'application_id': 'app_interview_1',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ApplicationChatPage), findsOneWidget);
    },
  );

  testWidgets(
    'a foreground work_schedule_confirmed push bumps the seeker badge signal '
    'and shows a snackbar', (tester) async {
      await pumpApp(tester);
      final before = SeekerApplicationUpdateSignal.ping.value;

      await PushIncomingHandler.handleForeground(
        const RemoteMessage(
          data: {
            'type': 'work_schedule_confirmed',
            'application_id': 'app_work_2',
          },
          notification: RemoteNotification(
            title: '근무 일정이 확정되었습니다',
            body: '「창고 피킹」 근무 일정이 확정되었습니다.',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(SeekerApplicationUpdateSignal.ping.value, before + 1);
      expect(find.text('「창고 피킹」 근무 일정이 확정되었습니다.'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ApplicationChatPage), findsOneWidget);
    },
  );

  testWidgets(
    'a foreground interview_confirmed push bumps the seeker badge signal',
    (tester) async {
      await pumpApp(tester);
      final before = SeekerApplicationUpdateSignal.ping.value;

      await PushIncomingHandler.handleForeground(
        const RemoteMessage(
          data: {
            'type': 'interview_confirmed',
            'application_id': 'app_interview_2',
          },
        ),
      );
      await tester.pump();

      expect(SeekerApplicationUpdateSignal.ping.value, before + 1);
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
