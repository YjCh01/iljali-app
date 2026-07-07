import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/chat/data/admin_announcement_local_data_source.dart';
import 'package:map/features/chat/domain/entities/admin_announcement.dart';
import 'package:map/features/chat/domain/entities/admin_announcement_audience.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';

/// 운영 공지 → 채팅 목록용 방
abstract final class AdminAnnouncementRoomService {
  static Future<List<CorporateChatRoom>> fetchNoticeRooms() async {
    final announcements =
        await const AdminAnnouncementLocalDataSourceImpl().fetchAll();
    if (announcements.isEmpty) return const [];

    final memberType = AuthSession.instance.currentUser?.memberType;
    final visible = announcements
        .where((item) => item.audience.visibleForMemberType(memberType))
        .toList(growable: false);
    if (visible.isEmpty) return const [];

    final readStore = await AdminAnnouncementReadStore.create();
    final readIds = readStore.readIds();

    return [
      for (final item in visible)
        _toRoom(item, read: readIds.contains(item.id)),
    ];
  }

  static CorporateChatRoom _toRoom(
    AdminAnnouncement item, {
    required bool read,
  }) {
    final sent = item.createdAt ?? DateTime.now();
    return CorporateChatRoom(
      id: 'admin_notice_${item.id}',
      applicantName: '일자리 운영팀',
      jobTitle: item.title,
      lastMessage: item.previewLine,
      updatedAtLabel: LocalHiringRepository.formatRelativeTime(sent),
      unreadCount: read ? 0 : 1,
      kind: CorporateChatRoomKind.adminNotice,
      fullMessageBody: item.body,
    );
  }

  static String? announcementIdFromRoomId(String roomId) {
    const prefix = 'admin_notice_';
    if (!roomId.startsWith(prefix)) return null;
    return roomId.substring(prefix.length);
  }
}
