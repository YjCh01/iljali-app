import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/hiring/presentation/widgets/chat/chat_room_leave_menu.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class CorporateChatRoomCard extends StatelessWidget {
  const CorporateChatRoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onLeave,
  });

  final CorporateChatRoom room;
  final VoidCallback? onTap;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: room.isReadOnlyNotice
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primaryLight.withValues(alpha: 0.35),
            child: room.isAdminNotice
                ? const Icon(Icons.campaign_outlined,
                    color: AppColors.primary, size: 22)
                : room.isOfficialNotice
                    ? const Icon(Icons.workspace_premium_outlined,
                        color: AppColors.primary, size: 22)
                    : Text(
                        room.applicantName.characters.first,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.applicantName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      room.updatedAtLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  room.jobTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  room.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (room.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${room.unreadCount}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          if (onLeave != null && !room.isReadOnlyNotice) ...[
            const SizedBox(width: 4),
            ChatRoomLeaveMenu(onLeave: onLeave!),
          ],
        ],
      ),
    );
  }
}

class CorporateMoreMenuCard extends StatelessWidget {
  const CorporateMoreMenuCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final CorporateMoreMenuItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFor(item.iconName),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '준비중',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
        'insights' => Icons.insights_outlined,
        'notifications' => Icons.notifications_none_rounded,
        'support' => Icons.support_agent_outlined,
        _ => Icons.more_horiz_rounded,
      };
}
