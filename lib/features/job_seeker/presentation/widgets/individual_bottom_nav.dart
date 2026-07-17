import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 구직자 하단 5탭 — 지도 · 보관함 · 내일자리 · 채팅 · 더보기
class IndividualBottomNav extends StatelessWidget {
  const IndividualBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isItemEnabled,
    this.myJobsBadgeCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool Function(int index)? isItemEnabled;
  final int myJobsBadgeCount;

  /// "내일자리" 탭(인덱스 2)에 미확인 배지를 얹은 네비 항목 목록.
  static List<WebNavEntry> buildEntries({int myJobsBadgeCount = 0}) => [
        const WebNavEntry(icon: Icons.map_outlined, label: '지도'),
        const WebNavEntry(icon: Icons.bookmark_outline_rounded, label: '보관함'),
        WebNavEntry(
          icon: Icons.work_outline_rounded,
          label: '내일자리',
          badgeCount: myJobsBadgeCount,
        ),
        const WebNavEntry(icon: Icons.chat_bubble_outline_rounded, label: '채팅'),
        const WebNavEntry(icon: Icons.more_horiz_rounded, label: '더보기'),
      ];

  @override
  Widget build(BuildContext context) {
    final entries = buildEntries(myJobsBadgeCount: myJobsBadgeCount);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(entries.length, (index) {
              final item = entries[index];
              final selected = currentIndex == index;
              final enabled = isItemEnabled?.call(index) ?? true;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: enabled ? 1 : 0.38,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.primaryLight
                                        .withValues(alpha: 0.28)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.primaryLight
                                          .withValues(alpha: 0.75),
                                  width: selected ? 2 : 1.5,
                                ),
                              ),
                              child: Icon(
                                item.icon,
                                size: 22,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            if (item.badgeCount > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: NavBadgeDot(count: item.badgeCount),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
