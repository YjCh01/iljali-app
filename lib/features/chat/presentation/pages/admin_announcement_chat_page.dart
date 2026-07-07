import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/chat/data/admin_announcement_local_data_source.dart';
import 'package:map/features/chat/domain/services/admin_announcement_room_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 운영 공지 — 읽기 전용 (답장 불가)
class AdminAnnouncementChatPage extends StatefulWidget {
  const AdminAnnouncementChatPage({super.key, required this.room});

  final CorporateChatRoom room;

  @override
  State<AdminAnnouncementChatPage> createState() =>
      _AdminAnnouncementChatPageState();
}

class _AdminAnnouncementChatPageState extends State<AdminAnnouncementChatPage> {
  @override
  void initState() {
    super.initState();
    _markRead();
  }

  Future<void> _markRead() async {
    final id = AdminAnnouncementRoomService.announcementIdFromRoomId(
      widget.room.id,
    );
    if (id == null || id.isEmpty) return;
    final store = await AdminAnnouncementReadStore.create();
    await store.markRead(id);
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.room.fullMessageBody ?? widget.room.lastMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text(
          '일자리 공지',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    widget.room.updatedAtLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: AppColors.searchBarBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 18,
                              color: AppColors.primary.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '일자리 운영팀',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.room.jobTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.textPrimary.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CorporateSurfaceCard(
                  child: Text(
                    '운영 공지는 확인만 가능합니다. 답장은 지원·문의 채팅을 이용해 주세요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
