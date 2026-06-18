/// 채팅 메시지 유형
enum ChatMessageKind {
  text,
  photo,
  resume,
  bankAccount,
  idCard,
}

extension ChatMessageKindX on ChatMessageKind {
  String get label => switch (this) {
        ChatMessageKind.text => '메시지',
        ChatMessageKind.photo => '사진',
        ChatMessageKind.resume => '이력서',
        ChatMessageKind.bankAccount => '통장사본',
        ChatMessageKind.idCard => '신분증',
      };

  static ChatMessageKind parse(String? raw) {
    if (raw == null) return ChatMessageKind.text;
    for (final value in ChatMessageKind.values) {
      if (value.name == raw) return value;
    }
    return ChatMessageKind.text;
  }
}
