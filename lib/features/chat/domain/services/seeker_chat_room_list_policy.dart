import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';

/// 구직자 채팅 탭 — 목록에 표시할 지원 건 (거절·노쇼 제외, 완료 건은 이력·채팅 열람 허용)
abstract final class SeekerChatRoomListPolicy {
  static bool isVisibleInChatList(HiringApplication application) =>
      application.status.isActive;

  static List<HiringApplication> filterForChatList(
    List<HiringApplication> applications,
  ) =>
      applications.where(isVisibleInChatList).toList(growable: false);
}
