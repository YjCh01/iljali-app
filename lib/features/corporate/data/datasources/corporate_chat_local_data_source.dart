import 'package:map/features/corporate/data/repositories/partnership_notice_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';

abstract class CorporateChatLocalDataSource {
  Future<List<CorporateChatRoom>> fetchChatRooms();
  Future<List<CorporateMoreMenuItem>> fetchMoreMenuItems();
}

class CorporateChatLocalDataSourceImpl implements CorporateChatLocalDataSource {
  const CorporateChatLocalDataSourceImpl();

  static const List<CorporateChatRoom> _applicantRooms = [];

  static const _moreItems = [
    CorporateMoreMenuItem(
      id: 'more_stats',
      title: '채용 통계',
      description: '공고·지원·합격률 리포트',
      iconName: 'insights',
    ),
    CorporateMoreMenuItem(
      id: 'more_notice',
      title: '알림 설정',
      description: '지원·근태·채팅 알림 관리',
      iconName: 'notifications',
    ),
    CorporateMoreMenuItem(
      id: 'more_support',
      title: '고객센터',
      description: '문의·FAQ·운영 지원',
      iconName: 'support',
    ),
  ];

  @override
  Future<List<CorporateChatRoom>> fetchChatRooms() async {
    final rooms = List<CorporateChatRoom>.from(_applicantRooms);
    final noticeRepo = await PartnershipNoticeRepository.create();
    if (await noticeRepo.isSent) {
      final body = await noticeRepo.body ?? '';
      final sentAt = await noticeRepo.sentAt;
      final label = _formatSentLabel(sentAt);
      rooms.insert(
        0,
        CorporateChatRoom(
          id: 'chat_official_partnership',
          applicantName: '일자리 운영팀',
          jobTitle: '푸시·패키지 안내',
          lastMessage: '기본 플랜 1km · 패키지 · 일용직·상시직 수수료 안내',
          updatedAtLabel: label,
          unreadCount: 1,
          kind: CorporateChatRoomKind.officialNotice,
          fullMessageBody: body,
        ),
      );
    }
    return List.unmodifiable(rooms);
  }

  String _formatSentLabel(DateTime? sentAt) {
    if (sentAt == null) return '방금';
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '오늘';
  }

  @override
  Future<List<CorporateMoreMenuItem>> fetchMoreMenuItems() async =>
      List.unmodifiable(_moreItems);
}
