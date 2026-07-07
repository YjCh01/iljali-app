/// 채팅방 종류
enum CorporateChatRoomKind {
  applicant,
  officialNotice,
  adminNotice,
}

/// 채팅방 목록용 엔티티
class CorporateChatRoom {
  const CorporateChatRoom({
    required this.id,
    required this.applicantName,
    required this.jobTitle,
    required this.lastMessage,
    required this.updatedAtLabel,
    required this.unreadCount,
    this.kind = CorporateChatRoomKind.applicant,
    this.fullMessageBody,
    this.jobPostId,
  });

  final String id;
  final String applicantName;
  final String jobTitle;
  final String lastMessage;
  final String updatedAtLabel;
  final int unreadCount;
  final CorporateChatRoomKind kind;
  final String? fullMessageBody;
  final String? jobPostId;

  bool get isOfficialNotice => kind == CorporateChatRoomKind.officialNotice;

  bool get isAdminNotice => kind == CorporateChatRoomKind.adminNotice;

  bool get isReadOnlyNotice => isOfficialNotice || isAdminNotice;
}

/// 6번 탭 — 예약 메뉴
class CorporateMoreMenuItem {
  const CorporateMoreMenuItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
}
