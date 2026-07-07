import 'package:flutter/material.dart';
import 'package:map/core/hiring/chat_room_leave_service.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/commission_chat_prompt_service.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/features/corporate/data/datasources/corporate_chat_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_chat_rooms_usecase.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_chat_room_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/chat/presentation/pages/admin_announcement_chat_page.dart';
import 'package:map/features/corporate/presentation/pages/official_notice_chat_page.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/hiring/presentation/widgets/commission_payment_dialog.dart';

/// 기업회원 5번 탭 — 지원자 채팅방
class CorporateChatTab extends StatefulWidget {
  const CorporateChatTab({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<CorporateChatTab> createState() => _CorporateChatTabState();
}

class _CorporateChatTabState extends State<CorporateChatTab> {
  final _getChatRooms = const GetCorporateChatRoomsUseCase(
    CorporateChatLocalDataSourceImpl(),
  );

  List<CorporateChatRoom> _rooms = [];
  bool _loading = true;
  int _pendingCommissionCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant CorporateChatTab oldWidget) {
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
    setState(() => _loading = true);
    final rooms = await _getChatRooms();
    final myEmail = AuthSession.instance.currentUser?.email ?? '';
    final repo = await LocalHiringRepository.create();
    final prompt = await CommissionChatPromptService.create();
    final pendingCommissions = ProductFeatureFlags.isHiringCommissionEnabled
        ? (myEmail.isNotEmpty
            ? await repo.fetchPendingCommissionsForPayer(myEmail)
            : await repo.fetchPendingCommissions())
        : const <HiringApplication>[];
    final promptIds = ProductFeatureFlags.isHiringCommissionEnabled
        ? (myEmail.isNotEmpty
            ? await prompt.consumePendingForEmail(myEmail)
            : await prompt.consumePending())
        : const <String>[];

    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _pendingCommissionCount = pendingCommissions.length;
      _loading = false;
    });

    if (!widget.isActive) return;

    for (final applicationId in promptIds) {
      final app = await repo.findById(applicationId);
      if (app == null || !mounted) continue;
      if (!app.needsCommissionPayment) continue;
      await _showCommissionPrompt(app);
      break;
    }
  }

  Future<void> _showCommissionPrompt(HiringApplication app) async {
    if (!ProductFeatureFlags.isHiringCommissionEnabled || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${app.seekerName}님과 출근 확인이 완료되었습니다. 수수료 결제를 진행해 주세요.',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '결제',
          onPressed: () async {
            await showCommissionPaymentDialog(context, app);
            if (mounted) await _load();
          },
        ),
      ),
    );
    await showCommissionPaymentDialog(context, app);
    if (mounted) await _load();
  }

  Future<void> _openRoom(CorporateChatRoom room) async {
    if (room.isAdminNotice) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminAnnouncementChatPage(room: room),
        ),
      );
      if (mounted) await _load();
      return;
    }
    if (room.isOfficialNotice) {
      final renewed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => OfficialNoticeChatPage(room: room),
        ),
      );
      if (mounted) await _load();
      if (renewed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('노출이 연장되었습니다.')),
        );
      }
      return;
    }

    final policy = ChatAccessPolicy.evaluatePair(
      requester: MemberType.corporate,
      peer: MemberType.individual,
    );
    if (!policy.allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policy.message ?? '채팅 접근이 제한되었습니다.')),
      );
      return;
    }
    if (!mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ApplicationChatPage(applicationId: room.id),
      ),
    );
    if (updated == true && mounted) await _load();
  }

  Future<void> _leaveRoom(CorporateChatRoom room) async {
    final left = await ChatRoomLeaveService.confirmAndLeave(
      context,
      applicationId: room.id,
      roomTitle: room.applicantName,
      roomSubtitle: room.jobTitle,
    );
    if (left && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final showEmpty = _rooms.isEmpty;
    final itemCount = (_pendingCommissionCount > 0 ? 1 : 0) +
        (showEmpty ? 1 : 0) +
        _rooms.length;

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
            var cursor = 0;
            if (_pendingCommissionCount > 0) {
              if (index == cursor) {
                return _CommissionBanner(count: _pendingCommissionCount);
              }
              cursor++;
            }
            if (showEmpty) {
              if (index == cursor) {
                return const _EmptyChatCard();
              }
              cursor++;
            }
            final room = _rooms[index - cursor];
            return CorporateChatRoomCard(
              room: room,
              onTap: () => _openRoom(room),
              onLeave: room.isReadOnlyNotice ? null : () => _leaveRoom(room),
            );
          },
        ),
      ),
    );
  }
}

class _CommissionBanner extends StatelessWidget {
  const _CommissionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFFC62828)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '출근 확인 완료 · 수수료 결제 대기 $count건',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatCard extends StatelessWidget {
  const _EmptyChatCard();

  @override
  Widget build(BuildContext context) {
    return const CorporateSurfaceCard(
      child: Text(
        '아직 채팅 중인 지원자가 없습니다.\n지원자가 있으면 여기에 표시됩니다.',
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }
}
