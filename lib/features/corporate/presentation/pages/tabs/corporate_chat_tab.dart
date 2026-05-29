import 'package:flutter/material.dart';
import 'package:map/core/compliance/presentation/partnership_upsell_dialog.dart';
import 'package:map/core/compliance/services/contact_entitlement_service.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/datasources/corporate_chat_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_chat_rooms_usecase.dart';
import 'package:map/features/corporate/presentation/pages/partnership_notice_chat_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_chat_room_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 기업회원 5번 탭 — 지원자·운영팀 채팅방
class CorporateChatTab extends StatefulWidget {
  const CorporateChatTab({super.key});

  @override
  State<CorporateChatTab> createState() => _CorporateChatTabState();
}

class _CorporateChatTabState extends State<CorporateChatTab> {
  final _getChatRooms = const GetCorporateChatRoomsUseCase(
    CorporateChatLocalDataSourceImpl(),
  );

  List<CorporateChatRoom> _rooms = [];
  bool _loading = true;
  bool _contactAllowed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CorporateChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    var allowed = false;
    if (profile != null) {
      final access =
          await ContactEntitlementService().evaluateWithUsage(profile);
      allowed = access.allowed;
    }
    final rooms = await _getChatRooms();
    if (!mounted) return;
    setState(() {
      _contactAllowed = allowed;
      _rooms = allowed
          ? rooms
          : rooms.where((r) => r.isOfficialNotice).toList();
      _loading = false;
    });
  }

  void _openRoom(CorporateChatRoom room) {
    if (room.isOfficialNotice) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PartnershipNoticeChatPage(room: room),
        ),
      );
      setState(() {
        _rooms = _rooms.map((item) {
          if (item.id != room.id) return item;
          return CorporateChatRoom(
            id: item.id,
            applicantName: item.applicantName,
            jobTitle: item.jobTitle,
            lastMessage: item.lastMessage,
            updatedAtLabel: item.updatedAtLabel,
            unreadCount: 0,
            kind: item.kind,
            fullMessageBody: item.fullMessageBody,
          );
        }).toList();
      });
      return;
    }
    if (!_contactAllowed) {
      final profile = AuthSession.instance.currentUser?.corporateProfile;
      if (profile != null) {
        ContactEntitlementService().evaluateWithUsage(profile).then((access) {
          if (!mounted) return;
          ensureContactAccess(context, access);
        });
      }
      return;
    }
    showCorporateComingSoonSnackBar(context, '${room.applicantName} 채팅');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: (_contactAllowed ? 0 : 1) + _rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (!_contactAllowed && index == 0) {
              return CorporateSurfaceCard(
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.corporatePushPackageShop),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '지원자 채팅 이용 제한',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '계정·사업자 검증 상태를 확인해 주세요. '
                      '지역 푸시권은 채용 알림 확장용입니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              );
            }
            final roomIndex = _contactAllowed ? index : index - 1;
            final room = _rooms[roomIndex];
            return CorporateChatRoomCard(
              room: room,
              onTap: () => _openRoom(room),
            );
          },
        ),
      ),
    );
  }
}
