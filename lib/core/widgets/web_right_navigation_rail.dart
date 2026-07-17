import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 웹 900px+ 레이아웃 기준 (AdaptiveSheet와 동일)
abstract final class WebLayoutBreakpoints {
  static const wide = 900.0;
  static const railWidth = 88.0;

  /// 알바몬·에펨코리아 등 일반 웹처럼 본문 최대 폭 (우측 레일 포함)
  static const siteFrameMaxWidth = 1140.0;

  /// 좁은 wide 웹에서도 좌·우 여백이 남도록
  static const minSideGutter = 24.0;

  /// 좌·우 광고·여백 — 일반 웹처럼 흰 배경
  static const sideGutterColor = Colors.white;

  static bool isWideWeb(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= wide;
}

class WebNavEntry {
  const WebNavEntry({required this.icon, required this.label, this.badgeCount = 0});

  final IconData icon;
  final String label;
  final int badgeCount;
}

/// 아이콘 우측 상단 배지 — 미확인 건수 표시
class NavBadgeDot extends StatelessWidget {
  const NavBadgeDot({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// 넓은 웹 — 하단 탭 그리드를 **우측** 세로 네비로 배치
class WebRightNavigationRail extends StatelessWidget {
  const WebRightNavigationRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.width = WebLayoutBreakpoints.railWidth,
    this.header,
    this.footer,
    this.isItemEnabled,
  });

  final List<WebNavEntry> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double width;
  final Widget? header;
  final Widget? footer;
  final bool Function(int index)? isItemEnabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            left: BorderSide(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (header != null) ...[
                header!,
                const SizedBox(height: 8),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (var index = 0; index < items.length; index++)
                      _RailItem(
                        item: items[index],
                        selected: currentIndex == index,
                        enabled: isItemEnabled?.call(index) ?? true,
                        onTap: () => onTap(index),
                      ),
                  ],
                ),
              ),
              if (footer != null) footer!,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final WebNavEntry item;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
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
                    if (item.badgeCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: NavBadgeDot(count: item.badgeCount),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
