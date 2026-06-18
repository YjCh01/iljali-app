import 'package:map/core/hiring/chat_message_kind.dart';

/// 지원 건별 채팅 메시지 (로컬 영속)
class ApplicationChatMessage {
  const ApplicationChatMessage({
    required this.fromEmployer,
    required this.text,
    required this.sentAt,
    this.isSystem = false,
    this.kind = ChatMessageKind.text,
    this.attachmentPath,
  });

  final bool fromEmployer;
  final String text;
  final DateTime sentAt;
  final bool isSystem;
  final ChatMessageKind kind;
  final String? attachmentPath;

  bool get hasAttachment =>
      attachmentPath != null && attachmentPath!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'fromEmployer': fromEmployer,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'isSystem': isSystem,
        'kind': kind.name,
        if (attachmentPath != null) 'attachmentPath': attachmentPath,
      };

  factory ApplicationChatMessage.fromJson(Map<String, dynamic> json) {
    return ApplicationChatMessage(
      fromEmployer: json['fromEmployer'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '') ??
          DateTime.now(),
      isSystem: json['isSystem'] as bool? ?? false,
      kind: ChatMessageKindX.parse(json['kind'] as String?),
      attachmentPath: json['attachmentPath'] as String?,
    );
  }
}
