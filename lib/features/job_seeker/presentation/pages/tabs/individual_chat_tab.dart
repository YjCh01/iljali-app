import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/chat_room_leave_service.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/seeker_attendance_gate_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/features/hiring/presentation/widgets/chat/chat_room_leave_menu.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 구직자 5번 탭 — 기업 채팅 (↔ 기업 채팅)
class IndividualChatTab extends StatefulWidget {
  const IndividualChatTab({super.key});

  @override
  State<IndividualChatTab> createState() => _IndividualChatTabState();
}

class _IndividualChatTabState extends State<IndividualChatTab> {
  SeekerAttendanceGateResult? _gate;
  List<HiringApplication> _applications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
    final active = apps
        .where((a) =>
            a.status != HiringApplicationStatus.rejected &&
            a.status != HiringApplicationStatus.noShow &&
            a.status != HiringApplicationStatus.commissionPaid)
        .toList();
    final visible = await ChatRoomLeaveService.filterVisible(
      items: active,
      applicationIdOf: (a) => a.id,
      userEmail: email,
    );
    if (mounted) {
      setState(() {
        _gate = gate;
        _applications = visible;
        _loading = false;
      });
    }
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

    if (_applications.isEmpty && _gate?.isLocked != true) {
      return ColoredBox(
        color: AppColors.background,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: const [
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

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: _applications.length + (_gate?.isLocked == true ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (_gate?.isLocked == true && index == 0) {
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
            final roomIndex = _gate?.isLocked == true ? index - 1 : index;
            final app = _applications[roomIndex];
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
                  Text(
                    LocalHiringRepository.formatRelativeTime(app.appliedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
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
