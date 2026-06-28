import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

/// 기업회원 하단 6탭 네비게이션
class CorporateBottomNav extends StatelessWidget {
  const CorporateBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isItemEnabled,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool Function(int index)? isItemEnabled;

  static const entries = <WebNavEntry>[
    WebNavEntry(icon: Icons.home_rounded, label: '홈'),
    WebNavEntry(icon: Icons.article_outlined, label: '공고'),
    WebNavEntry(icon: Icons.people_outline_rounded, label: '지원자'),
    WebNavEntry(icon: Icons.schedule_outlined, label: '근태'),
    WebNavEntry(icon: Icons.chat_bubble_outline_rounded, label: '채팅'),
    WebNavEntry(icon: Icons.more_horiz_rounded, label: '더보기'),
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
                        if (item.label.isNotEmpty) ...[
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
