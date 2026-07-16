import 'package:flutter/foundation.dart';
import 'package:map/core/hiring/chat_read_marker_service.dart';
import 'package:map/core/hiring/chat_room_leave_service.dart';
import 'package:map/core/dev/dev_chat_test_support.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/chat/domain/services/admin_announcement_room_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/services/exposure_renewal_service.dart';

abstract class CorporateChatLocalDataSource {
  Future<List<CorporateChatRoom>> fetchChatRooms();
  Future<List<CorporateMoreMenuItem>> fetchMoreMenuItems();
}

class CorporateChatLocalDataSourceImpl implements CorporateChatLocalDataSource {
  const CorporateChatLocalDataSourceImpl();

  static const _moreItems = [
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
    if (kDebugMode) {
      await DevChatTestSupport.ensureCorporateChatReady();
    }

    var companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    if (kDebugMode) {
      final email = AuthSession.instance.currentUser?.email;
      final devCorp =
          email != null ? DevTestAccounts.corporateByEmail(email) : null;
      if (devCorp != null) {
        companyKey = devCorp.verifiedCorporateProfile!.companyKey;
      }
    }
    if (companyKey == null || companyKey.isEmpty) return [];

    final repo = await LocalHiringRepository.create();
    final chatRepo = await ApplicationChatMessageRepository.create();
    final applications =
        await repo.fetchApplicantsForCorporate(companyKey: companyKey);
    final noticeRooms =
        await ExposureRenewalNoticeService().fetchNoticeRooms(
      companyKey: companyKey,
    );
    final adminNotices = await AdminAnnouncementRoomService.fetchNoticeRooms();
    final rooms = <CorporateChatRoom>[...adminNotices, ...noticeRooms];
    final userEmail = AuthSession.instance.currentUser?.email ?? '';
    for (final app in applications) {
      if (app.status == HiringApplicationStatus.rejected ||
          app.status == HiringApplicationStatus.noShow ||
          app.status == HiringApplicationStatus.commissionPaid) {
        continue;
      }
      if (userEmail.isNotEmpty &&
          await ChatRoomLeaveService.isLeft(
            applicationId: app.id,
            userEmail: userEmail,
          )) {
        continue;
      }
      rooms.add(await _mapApplication(app, chatRepo));
    }
    return rooms;
  }

  Future<CorporateChatRoom> _mapApplication(
    HiringApplication app,
    ApplicationChatMessageRepository chatRepo,
  ) async {
    final messages = await chatRepo.load(app.id);
    final lastChat = messages.isNotEmpty ? messages.last : null;

    final lastMessage = lastChat != null
        ? _previewLine(lastChat.text)
        : ProductFeatureFlags.isHiringCommissionEnabled &&
                app.needsCommissionPayment
            ? '출근 확인 완료 · 수수료 ${CommissionCalculator.formatKrw(CommissionCalculator.forApplication(app))} 결제 필요'
            : ProductFeatureFlags.isHiringCommissionEnabled &&
                    app.isWorkAgreementComplete
                ? '근무 일정 합의 완료 · ${app.status.label}'
                : '지원 접수 · ${app.status.label}';

    final unreadCount = await ChatReadMarkerService.unreadCount(
      applicationId: app.id,
      asEmployer: true,
      messages: messages,
    );

    return CorporateChatRoom(
      id: app.id,
      applicantName: app.seekerName,
      jobTitle: app.postTitle,
      lastMessage: lastMessage,
      updatedAtLabel: LocalHiringRepository.formatRelativeTime(
        lastChat?.sentAt ?? app.appliedAt,
      ),
      unreadCount: unreadCount,
    );
  }

  String _previewLine(String text) {
    final line = text.replaceAll('\n', ' ').trim();
    if (line.length <= 64) return line;
    return '${line.substring(0, 64)}…';
  }

  @override
  Future<List<CorporateMoreMenuItem>> fetchMoreMenuItems() async =>
      List.unmodifiable(_moreItems);
}
