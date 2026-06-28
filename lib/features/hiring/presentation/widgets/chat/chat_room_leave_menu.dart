import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 채팅 목록·채팅 화면 공통 — 대화방 나가기 메뉴
class ChatRoomLeaveMenu extends StatelessWidget {
  const ChatRoomLeaveMenu({
    super.key,
    required this.onLeave,
    this.useHamburgerIcon = false,
    this.iconColor,
  });

  final VoidCallback onLeave;
  final bool useHamburgerIcon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        useHamburgerIcon ? Icons.menu_rounded : Icons.more_vert_rounded,
        color: iconColor ?? AppColors.textSecondary,
      ),
      tooltip: '메뉴',
      onSelected: (value) {
        if (value == 'leave') onLeave();
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'leave',
          child: Text('대화방 나가기'),
        ),
      ],
    );
  }
}
