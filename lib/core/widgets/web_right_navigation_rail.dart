import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 웹 900px+ 레이아웃 기준 (AdaptiveSheet와 동일)
abstract final class WebLayoutBreakpoints {
  static const wide = 900.0;
  static const railWidth = 88.0;

  static bool isWideWeb(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= wide;
}

class WebNavEntry {
  const WebNavEntry({required this.icon, required this.label});

  final IconData icon;
  final String label;
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
