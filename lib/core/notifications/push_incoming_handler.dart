import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:map/core/navigation/global_navigator.dart';
import 'package:map/features/corporate/domain/services/corporate_new_applicant_signal.dart';
import 'package:map/features/corporate/presentation/pages/corporate_applicant_resume_page.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_push_inbox_repository.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';
import 'package:map/features/job_seeker/domain/services/seeker_application_update_signal.dart';

const _confirmationPushTypes = {'work_schedule_confirmed', 'interview_confirmed'};

/// FCM 수신 — 받은함 기록 + 탭 시 앱 내 채팅방으로 딥링크
abstract final class PushIncomingHandler {
  static Future<void> handleForeground(RemoteMessage message) async {
    await _persistJobPushIfNeeded(message);
    _notifyNewApplicantIfNeeded(message);
    _notifyConfirmationIfNeeded(message);
  }

  static Future<void> handleBackground(RemoteMessage message) async {
    await _persistJobPushIfNeeded(message);
  }

  static Future<void> handleOpenedApp(RemoteMessage message) async {
    await _persistJobPushIfNeeded(message);
    _openChatIfNeeded(message);
  }

  static void _openChatIfNeeded(RemoteMessage message) {
    final data = message.data;
    final applicationId = data['application_id'] as String?;
    if (applicationId == null || applicationId.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (data['type']) {
      case 'chat_message':
      case 'work_schedule_confirmed':
      case 'interview_confirmed':
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ApplicationChatPage(applicationId: applicationId),
          ),
        );
      case 'new_applicant':
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CorporateApplicantResumePage(applicationId: applicationId),
          ),
        );
    }
  }

  static void _notifyNewApplicantIfNeeded(RemoteMessage message) {
    if (message.data['type'] != 'new_applicant') return;
    CorporateNewApplicantSignal.notify();

    final applicationId = message.data['application_id'] as String?;
    final body = message.notification?.body ?? '새 지원자가 도착했습니다.';
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body),
          behavior: SnackBarBehavior.floating,
          action: applicationId == null || applicationId.isEmpty
              ? null
              : SnackBarAction(
                  label: '확인',
                  onPressed: () {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => CorporateApplicantResumePage(
                          applicationId: applicationId,
                        ),
                      ),
                    );
                  },
                ),
        ),
      );
  }

  static void _notifyConfirmationIfNeeded(RemoteMessage message) {
    final type = message.data['type'];
    if (!_confirmationPushTypes.contains(type)) return;
    SeekerApplicationUpdateSignal.notify();

    final applicationId = message.data['application_id'] as String?;
    final body = message.notification?.body ??
        (type == 'interview_confirmed'
            ? '면접 일정이 확정되었습니다.'
            : '근무 일정이 확정되었습니다.');
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body),
          behavior: SnackBarBehavior.floating,
          action: applicationId == null || applicationId.isEmpty
              ? null
              : SnackBarAction(
                  label: '확인',
                  onPressed: () {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ApplicationChatPage(applicationId: applicationId),
                      ),
                    );
                  },
                ),
        ),
      );
  }

  static Future<void> _persistJobPushIfNeeded(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] != 'job_recruitment') return;

    final title = message.notification?.title ??
        data['title'] as String? ??
        '근처 새 일자리';
    final body = message.notification?.body ??
        data['company_name'] as String? ??
        '';
    final postId = data['post_id'] as String?;

    try {
      final repo = await SeekerPushInboxRepository.create();
      await repo.recordPush(
        SeekerPushNotification(
          id: postId ?? 'push_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          body: body,
          companyName: data['company_name'] as String? ?? '채용 기업',
          jobPostId: postId,
          receivedAt: DateTime.now(),
        ),
      );
    } on Object catch (error, stack) {
      debugPrint('push inbox persist failed: $error\n$stack');
    }
  }
}
