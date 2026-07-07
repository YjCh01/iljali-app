import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/chat/data/admin_announcement_local_data_source.dart';
import 'package:map/features/chat/domain/entities/admin_announcement.dart';
import 'package:map/features/chat/domain/entities/admin_announcement_audience.dart';
import 'package:map/features/chat/domain/services/admin_announcement_room_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    AdminAnnouncementLocalDataSourceImpl.replaceFromServer(const []);
    await AuthSession.instance.signOut();
  });

  test('fromJson maps server fields', () {
    final item = AdminAnnouncement.fromJson({
      'id': 'announce_abc',
      'title': '점검 안내',
      'body': '오늘 22시 점검',
      'audience': 'corporate',
      'push_requested': true,
      'created_at': '2026-06-19T10:00:00',
    });
    expect(item.id, 'announce_abc');
    expect(item.title, '점검 안내');
    expect(item.audience, AdminAnnouncementAudience.corporate);
    expect(item.pushRequested, isTrue);
    expect(item.previewLine, '오늘 22시 점검');
  });

  test('fetchNoticeRooms maps to admin notice chat room', () async {
    AdminAnnouncementLocalDataSourceImpl.replaceFromServer([
      const AdminAnnouncement(
        id: 'announce_1',
        title: '서비스 공지',
        body: '내용입니다',
        createdAt: null,
      ),
    ]);

    final rooms = await AdminAnnouncementRoomService.fetchNoticeRooms();
    expect(rooms, hasLength(1));
    expect(rooms.first.kind, CorporateChatRoomKind.adminNotice);
    expect(rooms.first.applicantName, '일자리 운영팀');
    expect(rooms.first.unreadCount, 1);
    expect(
      AdminAnnouncementRoomService.announcementIdFromRoomId(rooms.first.id),
      'announce_1',
    );
  });

  test('fetchNoticeRooms filters by member type', () async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '기업',
        email: 'corp@test.co.kr',
        memberType: MemberType.corporate,
      ),
    );
    AdminAnnouncementLocalDataSourceImpl.replaceFromServer([
      const AdminAnnouncement(
        id: 'announce_seeker',
        title: '구직자 공지',
        body: '개인만',
        audience: AdminAnnouncementAudience.seeker,
      ),
      const AdminAnnouncement(
        id: 'announce_corp',
        title: '기업 공지',
        body: '기업만',
        audience: AdminAnnouncementAudience.corporate,
      ),
    ]);

    final rooms = await AdminAnnouncementRoomService.fetchNoticeRooms();
    expect(rooms, hasLength(1));
    expect(rooms.single.jobTitle, '기업 공지');
  });
}
