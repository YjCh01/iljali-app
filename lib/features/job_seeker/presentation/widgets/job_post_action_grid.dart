import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 공고 상세 하단 — 문의 · 지원 · 북마크 정사각형 그리드
class JobPostActionGrid extends StatelessWidget {
  const JobPostActionGrid({
    super.key,
    required this.onInquire,
    required this.onApply,
    required this.onBookmark,
    this.isBookmarked = false,
    this.bookmarkBusy = false,
    this.previewMode = false,
    this.hasApplied = false,
    this.canWithdrawApplication = false,
    this.onWithdrawApply,
  });

  final VoidCallback onInquire;
  final VoidCallback onApply;
  final VoidCallback onBookmark;
  final bool isBookmarked;
  final bool bookmarkBusy;
  final bool previewMode;
  final bool hasApplied;
  final bool canWithdrawApplication;
  final VoidCallback? onWithdrawApply;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.searchBarBorder.withValues(alpha: 0.8)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '문의하기',
                  onTap: previewMode ? null : onInquire,
                  muted: previewMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: canWithdrawApplication
                      ? Icons.cancel_outlined
                      : hasApplied
                          ? Icons.check_circle_outline
                          : Icons.send_rounded,
                  label: canWithdrawApplication
                      ? '지원취소'
                      : hasApplied
                          ? '지원됨'
                          : '지원하기',
                  onTap: previewMode
                      ? null
                      : canWithdrawApplication
                          ? onWithdrawApply
                          : hasApplied
                              ? null
                              : onApply,
                  accent: !previewMode && !hasApplied,
                  muted: previewMode,
                  danger: canWithdrawApplication,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: isBookmarked ? '저장됨' : '북마크',
                  onTap: previewMode || bookmarkBusy ? null : onBookmark,
                  highlighted: isBookmarked,
                  muted: previewMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
    this.highlighted = false,
    this.muted = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool highlighted;
  final bool muted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? Colors.red.shade50
        : accent
            ? AppColors.primary
            : highlighted
                ? AppColors.primaryLight.withValues(alpha: 0.22)
                : AppColors.background;
    final fg = danger
        ? Colors.red.shade800
        : accent
            ? Colors.white
            : highlighted
                ? AppColors.primary
                : AppColors.textPrimary;

    return Material(
      color: muted ? AppColors.background.withValues(alpha: 0.6) : bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: muted
                      ? AppColors.textSecondary.withValues(alpha: 0.45)
                      : fg,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted
                        ? AppColors.textSecondary.withValues(alpha: 0.45)
                        : fg,
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
