import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/seeker_attendance_gate_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/mvp_feedback.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class _ChatPreview {
  const _ChatPreview({
    required this.company,
    required this.preview,
    required this.time,
  });

  final String company;
  final String preview;
  final String time;
}

/// 구직자 5번 탭 — 기업 채팅 (↔ 기업 채팅)
class IndividualChatTab extends StatefulWidget {
  const IndividualChatTab({super.key});

  @override
  State<IndividualChatTab> createState() => _IndividualChatTabState();
}

class _IndividualChatTabState extends State<IndividualChatTab> {
  SeekerAttendanceGateResult? _gate;

  @override
  void initState() {
    super.initState();
    _loadGate();
  }

  Future<void> _loadGate() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;
    final gate = await SeekerAttendanceGateService().evaluate(email);
    if (mounted) setState(() => _gate = gate);
  }

  static const _rooms = [
    _ChatPreview(
      company: '강남 지점',
      preview: '내일 9시 출근 가능하신가요?',
      time: '14:20',
    ),
    _ChatPreview(
      company: '역삼 지점',
      preview: '서류 검토 완료되었습니다.',
      time: '어제',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _rooms.length + (_gate?.isLocked == true ? 1 : 0),
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
          final room = _rooms[roomIndex];
          return CorporateSurfaceCard(
            onTap: _gate?.isLocked == true
                ? null
                : () => showMvpInfoSnackBar(context, '채팅방'),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.35),
                  child: const Icon(Icons.business, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.company,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  room.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
