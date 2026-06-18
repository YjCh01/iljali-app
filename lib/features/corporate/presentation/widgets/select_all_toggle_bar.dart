import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 체크 선택 목록 상단 — 모두 선택 / 선택 해제
class SelectAllToggleBar extends StatelessWidget {
  const SelectAllToggleBar({
    super.key,
    required this.allSelected,
    required this.onToggle,
    this.selectableCount = 0,
    this.selectedCount = 0,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.activeColor,
  });

  final bool allSelected;
  final VoidCallback onToggle;
  final int selectableCount;
  final int selectedCount;
  final bool enabled;
  final EdgeInsetsGeometry padding;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    if (selectableCount <= 0) return const SizedBox.shrink();

    final color = activeColor ?? AppColors.primary;

    return Padding(
      padding: padding,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onToggle : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: enabled ? (_) => onToggle() : null,
                  activeColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  allSelected ? '선택 해제' : '모두 선택',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary.withValues(alpha: 0.55),
                  ),
                ),
                const Spacer(),
                Text(
                  '$selectedCount/$selectableCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
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
