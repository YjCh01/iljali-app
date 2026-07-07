import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/features/chat/domain/services/seeker_chat_room_list_policy.dart';

HiringApplication _app(HiringApplicationStatus status) {
  return HiringApplication(
    id: 'app-$status',
    postId: 'post-1',
    postTitle: '테스트 공고',
    companyName: '테스트 기업',
    seekerEmail: 'seeker@test.com',
    seekerName: '홍길동',
    seekerPhoneMasked: '010-****-1234',
    workSchedule: '주간',
    status: status,
    appliedAt: DateTime(2026, 6, 1),
  );
}

void main() {
  test('completed applications stay visible for chat history', () {
    expect(
      SeekerChatRoomListPolicy.isVisibleInChatList(
        _app(HiringApplicationStatus.commissionPaid),
      ),
      isTrue,
    );
    expect(
      SeekerChatRoomListPolicy.isVisibleInChatList(
        _app(HiringApplicationStatus.checkedIn),
      ),
      isTrue,
    );
  });

  test('rejected and no-show are hidden from chat list', () {
    expect(
      SeekerChatRoomListPolicy.isVisibleInChatList(
        _app(HiringApplicationStatus.rejected),
      ),
      isFalse,
    );
    expect(
      SeekerChatRoomListPolicy.isVisibleInChatList(
        _app(HiringApplicationStatus.noShow),
      ),
      isFalse,
    );
  });
}
