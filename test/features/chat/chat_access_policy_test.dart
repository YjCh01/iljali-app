import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';

void main() {
  test('allows only corporate-seeker pair chat', () {
    final allowed = ChatAccessPolicy.evaluatePair(
      requester: MemberType.corporate,
      peer: MemberType.individual,
    );
    expect(allowed.allowed, isTrue);

    final seekerSeeker = ChatAccessPolicy.evaluatePair(
      requester: MemberType.individual,
      peer: MemberType.individual,
    );
    expect(seekerSeeker.allowed, isFalse);

    final corporateCorporate = ChatAccessPolicy.evaluatePair(
      requester: MemberType.corporate,
      peer: MemberType.corporate,
    );
    expect(corporateCorporate.allowed, isFalse);
  });

  test('denies group chats', () {
    final denied = ChatAccessPolicy.evaluatePair(
      requester: MemberType.corporate,
      peer: MemberType.individual,
      participantCount: 3,
    );
    expect(denied.allowed, isFalse);
    expect(denied.reason, ChatAccessDenyReason.groupChatNotAllowed);
  });
}
