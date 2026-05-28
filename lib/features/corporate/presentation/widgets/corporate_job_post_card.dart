import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 관리 — 압축 정보 카드
class CorporateJobPostCard extends StatelessWidget {
  const CorporateJobPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onExtraPush,
    this.onApplicantsTap,
    this.availablePushCredits,
  });

  final CorporateJobPost post;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onExtraPush;
  final VoidCallback? onApplicantsTap;
  final int? availablePushCredits;

  bool get _hasActions =>
      onEdit != null || onDelete != null || onExtraPush != null;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBadge(status: post.status),
                    const SizedBox(width: 8),
                    _EmploymentTypeBadge(type: post.employmentType),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.storefront_outlined,
                  text: _siteLocationLabel(post),
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  text: post.dailyWage != null
                      ? '시급 ${post.hourlyWage} · 일급 ${post.dailyWage}'
                      : '시급 ${post.hourlyWage}',
                ),
                if (post.paymentScheduleDisplayLabel != null) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    text: '급여지급 ${post.paymentScheduleDisplayLabel}',
                  ),
                ],
                if (post.notificationSettings?.hasConfiguredBase ?? false)
                  for (final label
                      in post.notificationSettings!.exposurePointLabels) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.notifications_active_outlined,
                      text: label,
                    ),
                  ],
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  text: post.workSchedule,
                ),
                const SizedBox(height: 12),
                Text(
                  post.fullDescriptionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 14),
          Row(
            children: [
              _MetaChip(
                icon: Icons.people_outline_rounded,
                label: '지원 ${post.applicantCount}명',
                highlighted: post.applicantCount > 0,
                onTap: post.applicantCount > 0 ? onApplicantsTap : null,
              ),
              const SizedBox(width: 8),
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                label: _formatDate(post.postedAt),
              ),
            ],
          ),
          if (_hasActions) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _ActionRow(
              onEdit: onEdit,
              onDelete: onDelete,
              onExtraPush: onExtraPush,
              extraPushEnabled:
                  post.notificationSettings?.hasConfiguredBase ?? false,
              availablePushCredits: availablePushCredits,
            ),
          ],
        ],
      ),
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.searchBarBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: content,
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '등록 ${date.year}.$month.$day';
  }

  static String _siteLocationLabel(CorporateJobPost post) {
    final location = post.branchName != null
        ? '${post.branchName} · ${post.warehouseName}'
        : post.warehouseName;
    return '소재지 $location';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CorporateJobPostStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CorporateJobPostStatus.recruiting => (
          AppColors.primaryLight.withValues(alpha: 0.28),
          AppColors.primary,
        ),
      CorporateJobPostStatus.closingSoon => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      CorporateJobPostStatus.closed => (
          AppColors.background,
          AppColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _EmploymentTypeBadge extends StatelessWidget {
  const _EmploymentTypeBadge({required this.type});

  final JobEmploymentType type;

  @override
  Widget build(BuildContext context) {
    final isPermanent = type == JobEmploymentType.permanent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPermanent
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPermanent
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.searchBarBorder,
        ),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isPermanent ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    this.onEdit,
    this.onDelete,
    this.onExtraPush,
    required this.extraPushEnabled,
    this.availablePushCredits,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onExtraPush;
  final bool extraPushEnabled;
  final int? availablePushCredits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: _ActionButton(
              label: '공고수정',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
          ),
        if (onEdit != null && (onDelete != null || onExtraPush != null))
          const SizedBox(width: 8),
        if (onDelete != null)
          Expanded(
            child: _ActionButton(
              label: '공고삭제',
              icon: Icons.delete_outline_rounded,
              onPressed: onDelete,
              destructive: true,
            ),
          ),
        if (onDelete != null && onExtraPush != null) const SizedBox(width: 8),
        if (onExtraPush != null)
          Expanded(
            child: _ActionButton(
              label: '지원자 모집하기',
              subtitle: availablePushCredits != null
                  ? '보유 $availablePushCredits회'
                  : null,
              icon: Icons.notifications_active_outlined,
              onPressed: extraPushEnabled ? onExtraPush : null,
              emphasized: true,
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.subtitle,
    this.destructive = false,
    this.emphasized = false,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : destructive
            ? const Color(0xFFC62828)
            : emphasized
                ? AppColors.primary
                : AppColors.textPrimary;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(
          color: enabled
              ? (emphasized
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.searchBarBorder)
              : AppColors.searchBarBorder.withValues(alpha: 0.6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: emphasized && enabled
                    ? AppColors.primary.withValues(alpha: 0.85)
                    : foreground.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.onTap,
  });

  static const _activeBg = Color(0xFFF3EEFF);
  static const _activeBorder = Color(0xFFD4C4FF);

  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? _activeBg : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: highlighted
            ? Border.all(color: _activeBorder)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlighted ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlighted
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          if (highlighted && onTap != null) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      ),
    );
  }
}
