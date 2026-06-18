import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 구직자 하단 6탭 — 지도 · 보관함 · 지원 · 근무 · 채팅 · 더보기
class IndividualBottomNav extends StatelessWidget {
  const IndividualBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.map_outlined, label: '지도'),
    _NavItem(icon: Icons.bookmark_outline_rounded, label: '보관함'),
    _NavItem(icon: Icons.description_outlined, label: '내 지원'),
    _NavItem(icon: Icons.event_available_outlined, label: '근무'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: '채팅'),
    _NavItem(icon: Icons.more_horiz_rounded, label: '더보기'),
  ];

  @override
  Widget build(BuildContext context) {
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
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.primaryLight.withValues(alpha: 0.28)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.primaryLight.withValues(alpha: 0.75),
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
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
