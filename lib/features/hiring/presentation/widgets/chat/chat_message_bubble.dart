import 'dart:io';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/chat_message_kind.dart';
import 'package:map/features/corporate/presentation/pages/corporate_applicant_resume_page.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.fromSelf,
    required this.applicationId,
  });

  final ApplicationChatMessage message;
  final bool fromSelf;
  final String applicationId;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: fromSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _onTap(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: fromSelf
                ? AppColors.primaryLight.withValues(alpha: 0.35)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: _Content(message: message),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    switch (message.kind) {
      case ChatMessageKind.resume:
        openCorporateApplicantResume(
          context,
          applicationId: applicationId,
        );
      case ChatMessageKind.photo:
      case ChatMessageKind.bankAccount:
      case ChatMessageKind.idCard:
        if (message.hasAttachment) {
          _openImageViewer(context, message.attachmentPath!);
        }
      case ChatMessageKind.text:
        break;
    }
  }

  void _openImageViewer(BuildContext context, String path) {
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부 파일을 불러올 수 없습니다.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _AttachmentImageViewerPage(
          title: message.kind.label,
          imagePath: path,
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.message});

  final ApplicationChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.photo && message.hasAttachment) {
      final file = File(message.attachmentPath!);
      if (file.existsSync()) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                file,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            if (message.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message.text, style: const TextStyle(fontSize: 13)),
            ],
          ],
        );
      }
    }

    if ((message.kind == ChatMessageKind.bankAccount ||
            message.kind == ChatMessageKind.idCard) &&
        message.hasAttachment) {
      final file = File(message.attachmentPath!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.kind == ChatMessageKind.idCard
                    ? Icons.badge_outlined
                    : Icons.account_balance_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                message.kind.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (file.existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                width: 200,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            message.text,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          Text(
            '탭하여 크게 보기',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
        ],
      );
    }

    if (message.kind == ChatMessageKind.resume) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '이력서',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.text,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          Text(
            '탭하여 이력서 보기',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
        ],
      );
    }

    return Text(message.text);
  }
}

class _AttachmentImageViewerPage extends StatelessWidget {
  const _AttachmentImageViewerPage({
    required this.title,
    required this.imagePath,
  });

  final String title;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}
