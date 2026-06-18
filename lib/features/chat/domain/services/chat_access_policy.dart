import 'package:map/core/session/member_type.dart';

enum ChatAccessDenyReason {
  groupChatNotAllowed,
  sameRoleNotAllowed,
}

class ChatAccessDecision {
  const ChatAccessDecision._({
    required this.allowed,
    this.reason,
    this.message,
  });

  const ChatAccessDecision.allow() : this._(allowed: true);

  const ChatAccessDecision.deny({
    required ChatAccessDenyReason reason,
    required String message,
  }) : this._(
          allowed: false,
          reason: reason,
          message: message,
        );

  final bool allowed;
  final ChatAccessDenyReason? reason;
  final String? message;
}

/// 채팅 접근 정책
/// - 그룹 채팅 금지
/// - 구직자↔구직자 금지
/// - 기업↔기업 금지
abstract final class ChatAccessPolicy {
  static ChatAccessDecision evaluatePair({
    required MemberType requester,
    required MemberType peer,
    int participantCount = 2,
  }) {
    if (participantCount != 2) {
      return const ChatAccessDecision.deny(
        reason: ChatAccessDenyReason.groupChatNotAllowed,
        message: '그룹 채팅은 지원하지 않습니다.',
      );
    }
    if (requester == peer) {
      return ChatAccessDecision.deny(
        reason: ChatAccessDenyReason.sameRoleNotAllowed,
        message: requester == MemberType.corporate
            ? '기업회원끼리의 채팅은 지원하지 않습니다.'
            : '구직자끼리의 채팅은 지원하지 않습니다.',
      );
    }
    return const ChatAccessDecision.allow();
  }
}
