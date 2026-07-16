import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/chat_read_marker_service.dart';
import 'package:map/core/hiring/chat_room_leave_service.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/seeker_attendance_gate_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/features/chat/domain/services/seeker_chat_room_list_policy.dart';
import 'package:map/features/hiring/presentation/widgets/chat/chat_room_leave_menu.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/chat/domain/services/admin_announcement_room_service.dart';
import 'package:map/features/chat/presentation/pages/admin_announcement_chat_page.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_chat_room_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/commute/presentation/widgets/bus_location_tower_pilot_entry_card.dart';

/// 구직자 5번 탭 — 기업 채팅 (↔ 기업 채팅)
class IndividualChatTab extends StatefulWidget {
  const IndividualChatTab({super.key, this.isActive = false});

  /// 활성 탭일 때만 목록 갱신
  final bool isActive;

  @override
  State<IndividualChatTab> createState() => _IndividualChatTabState();
}

class _IndividualChatTabState extends State<IndividualChatTab> {
  SeekerAttendanceGateResult? _gate;
  List<HiringApplication> _applications = [];
  List<CorporateChatRoom> _noticeRooms = const [];
  Map<String, int> _unreadCounts = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant IndividualChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load();
      return;
    }
    if (widget.isActive && HiringRefresh.consumeIfDirty()) {
      _load();
    }
  }

  Future<void> _load() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final gate = await SeekerAttendanceGateService().evaluate(email);
    final repo = await LocalHiringRepository.create();
    final apps = await repo.fetchForSeeker(email);
    final active = SeekerChatRoomListPolicy.filterForChatList(apps);
    final visible = await ChatRoomLeaveService.filterVisible(
      items: active,
      applicationIdOf: (a) => a.id,
      userEmail: email,
    );
    final noticeRooms = await AdminAnnouncementRoomService.fetchNoticeRooms();
    final chatRepo = await ApplicationChatMessageRepository.create();
    final unreadCounts = <String, int>{};
    for (final app in visible) {
      unreadCounts[app.id] = await ChatReadMarkerService.unreadCount(
        applicationId: app.id,
        asEmployer: false,
        messages: await chatRepo.load(app.id),
        userEmail: email,
      );
    }
    if (mounted) {
      setState(() {
        _gate = gate;
        _applications = visible;
        _noticeRooms = noticeRooms;
        _unreadCounts = unreadCounts;
        _loading = false;
      });
    }
  }

  Future<void> _openNotice(CorporateChatRoom room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminAnnouncementChatPage(room: room),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _leaveChat(HiringApplication app) async {
    final left = await ChatRoomLeaveService.confirmAndLeave(
      context,
      applicationId: app.id,
      roomTitle: app.companyName,
      roomSubtitle: '「${app.postTitle}」',
    );
    if (left && mounted) await _load();
  }

  Future<void> _openChat(HiringApplication app) async {
    if (_gate?.isLocked == true) return;
    final policy = ChatAccessPolicy.evaluatePair(
      requester: MemberType.individual,
      peer: MemberType.corporate,
    );
    if (!policy.allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policy.message ?? '채팅 접근이 제한되었습니다.')),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ApplicationChatPage(applicationId: app.id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final hasNotices = _noticeRooms.isNotEmpty;
    final hasApps = _applications.isNotEmpty;

    if (!hasApps && !hasNotices && _gate?.isLocked != true) {
      return ColoredBox(
        color: AppColors.background,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: const [
              BusLocationTowerPilotEntryCard(),
              SizedBox(height: 12),
              SizedBox(height: 48),
              Center(
                child: Text(
                  '진행 중인 채팅이 없습니다.\n공고 상세에서 문의하기로 기업과 대화를 시작하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final noticeCount = _noticeRooms.length;
    final bannerCount = _gate?.isLocked == true ? 1 : 0;
    final appCount = _applications.length;
    const pilotHeaderCount = 1;
    final itemCount = pilotHeaderCount + noticeCount + bannerCount + appCount;

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const BusLocationTowerPilotEntryCard();
            }
            final contentIndex = index - pilotHeaderCount;
            if (contentIndex < noticeCount) {
              final room = _noticeRooms[contentIndex];
              return CorporateChatRoomCard(
                room: room,
                onTap: () => _openNotice(room),
              );
            }
            final afterNotices = contentIndex - noticeCount;
            if (_gate?.isLocked == true && afterNotices == 0) {
              return MaterialBanner(
                backgroundColor: const Color(0xFFFFEBEE),
                content: Text(
                  _gate!.message ??
                      '미확인 출근 ${_gate!.overdueCount}건 — 출근 체크 후 채팅·지원이 가능합니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => ensureSeekerAttendanceAccess(
                      context,
                      AuthSession.instance.currentUser!.email,
                    ),
                    child: const Text('해결하기'),
                  ),
                ],
              );
            }
            final roomIndex = afterNotices - bannerCount;
            final app = _applications[roomIndex];
            final unread = _unreadCounts[app.id] ?? 0;
            return CorporateSurfaceCard(
              onTap: _gate?.isLocked == true ? null : () => _openChat(app),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primaryLight.withValues(alpha: 0.35),
                    child: const Icon(Icons.business, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.companyName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '「${app.postTitle}」 · ${app.status.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        LocalHiringRepository.formatRelativeTime(app.appliedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  ChatRoomLeaveMenu(onLeave: () => _leaveChat(app)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
