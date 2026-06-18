/// 담당자 채팅 — 빠른 답변 매크로
class ChatReplyMacro {
  const ChatReplyMacro({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  ChatReplyMacro copyWith({
    String? id,
    String? title,
    String? body,
  }) {
    return ChatReplyMacro(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };

  factory ChatReplyMacro.fromJson(Map<String, dynamic> json) {
    return ChatReplyMacro(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

abstract final class ChatReplyMacroDefaults {
  static const List<ChatReplyMacro> items = [
    ChatReplyMacro(
      id: 'macro_hiring_open',
      title: '채용 여부',
      body:
          '네, 「{공고명}」 공고는 현재 모집 중입니다.\n'
          '관심 가져주셔서 감사합니다.',
    ),
    ChatReplyMacro(
      id: 'macro_workplace',
      title: '근무지',
      body:
          '근무지는 {근무지} 입니다.\n'
          '근무 일정: {근무일정}',
    ),
    ChatReplyMacro(
      id: 'macro_job_detail',
      title: '업무 내용',
      body:
          '「{공고명}」 업무 안내드립니다.\n'
          '{업무내용}',
    ),
  ];
}
