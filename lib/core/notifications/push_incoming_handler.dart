import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:map/core/navigation/global_navigator.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_push_inbox_repository.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';

/// FCM 수신 — 받은함 기록 + 탭 시 앱 내 채팅방으로 딥링크
abstract final class PushIncomingHandler {
  static Future<void> handleForeground(RemoteMessage message) async {
    await _persistJobPushIfNeeded(message);
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
    if (data['type'] != 'chat_message') return;
    final applicationId = data['application_id'] as String?;
    if (applicationId == null || applicationId.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationChatPage(applicationId: applicationId),
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
