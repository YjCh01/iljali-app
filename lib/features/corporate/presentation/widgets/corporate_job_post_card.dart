import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/extra_push_availability.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/job_post_exposure_status_labels.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_display_labels.dart';
import 'package:map/features/corporate/presentation/widgets/urgent_hire_brand.dart';

/// 공고 관리 — 압축 정보 카드
class CorporateJobPostCard extends StatelessWidget {
  const CorporateJobPostCard({
    super.key,
    required this.post,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onClose,
    this.onCopy,
    this.onRepost,
    this.onConfigureExposure,
    this.onReactivateWorkplace,
    this.onRecruit,
    this.onManageExpansion,
    this.onOpenShop,
    this.onActivateShuttleOverlay,
    this.shuttleOverlayBusy = false,
    this.onApplicantsTap,
    this.extraPushAvailability,
    this.creditsDisplay,
  });

  final CorporateJobPost post;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClose;
  final VoidCallback? onCopy;
  final VoidCallback? onRepost;
  final VoidCallback? onConfigureExposure;
  final VoidCallback? onReactivateWorkplace;
  final VoidCallback? onRecruit;
  final VoidCallback? onManageExpansion;
  final VoidCallback? onOpenShop;
  final VoidCallback? onActivateShuttleOverlay;
  final bool shuttleOverlayBusy;
  final VoidCallback? onApplicantsTap;
  final ExtraPushAvailability? extraPushAvailability;
  final JobPostCardCreditsDisplay? creditsDisplay;

  bool get _isClosed => post.status == CorporateJobPostStatus.closed;

  bool get _hasActions =>
      onView != null ||
      onEdit != null ||
      onDelete != null ||
      onClose != null ||
      onCopy != null ||
      onRepost != null ||
      onConfigureExposure != null ||
      onRecruit != null ||
      onManageExpansion != null ||
      onOpenShop != null;

  Color get _titleColor => _isClosed
      ? AppColors.textSecondary.withValues(alpha: 0.55)
      : AppColors.textPrimary;

  Color get _bodyColor => _isClosed
      ? AppColors.textSecondary.withValues(alpha: 0.45)
      : AppColors.textSecondary.withValues(alpha: 0.95);

  VoidCallback? _action(VoidCallback? handler) =>
      _isClosed ? null : handler;

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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: _titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CorporateJobPostLabeledInfoRow(
                  icon: Icons.storefront_outlined,
                  label: CorporateJobPostDisplayLabels.siteLocation,
                  value: CorporateJobPostDisplayValues.siteLocation(post),
                  valueColor: _bodyColor,
                ),
                const SizedBox(height: 6),
                CorporateJobPostLabeledInfoRow(
                  icon: Icons.payments_outlined,
                  label: CorporateJobPostDisplayLabels.salary,
                  value: CorporateJobPostDisplayValues.salary(post),
                  valueColor: _bodyColor,
                ),
                const SizedBox(height: 6),
                CorporateJobPostLabeledInfoRow(
                  icon: Icons.schedule_outlined,
                  label: CorporateJobPostDisplayLabels.workSchedule,
                  value: CorporateJobPostDisplayValues.workSchedule(
                    post.workSchedule,
                  ),
                  valueColor: _bodyColor,
                ),
                const SizedBox(height: 12),
                Text(
                  post.fullDescriptionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _bodyColor,
                  ),
                ),
                const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: _MetaChip(
                  icon: Icons.people_outline_rounded,
                  label: '지원 ${post.applicantCount}명',
                  highlighted: !_isClosed && post.applicantCount > 0,
                  muted: _isClosed,
                  onTap: _isClosed || post.applicantCount <= 0
                      ? null
                      : onApplicantsTap,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: _formatDate(post.postedAt),
                  muted: _isClosed,
                ),
              ),
            ],
          ),
          if (_hasActions) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _ActionGrid(
              post: post,
              isClosed: _isClosed,
              onView: _action(onView),
              onEdit: _action(onEdit),
              onDelete: onDelete,
              onClose: _action(onClose),
              onCopy: _action(onCopy),
              onRepost: _action(onRepost),
              onManageExpansion: _action(onManageExpansion ?? onConfigureExposure),
              onReactivateWorkplace: _action(onReactivateWorkplace),
              onRecruit: _action(onRecruit),
              shuttleOverlayBusy: shuttleOverlayBusy,
              extraPushAvailability: extraPushAvailability,
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
        child: content,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '등록 ${date.year}.$month.$day';
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

class _CollapsiblePinSection extends StatefulWidget {
  const _CollapsiblePinSection({
    required this.title,
    required this.icon,
    required this.muted,
    required this.children,
  });

  final String title;
  final IconData icon;
  final bool muted;
  final List<Widget> children;

  @override
  State<_CollapsiblePinSection> createState() => _CollapsiblePinSectionState();
}

class _CollapsiblePinSectionState extends State<_CollapsiblePinSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.muted
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : AppColors.primary;
    final soft = widget.muted
        ? AppColors.background
        : AppColors.primaryLight.withValues(alpha: 0.14);
    final canExpand = widget.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: soft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: canExpand
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.muted
                      ? AppColors.searchBarBorder
                      : AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (canExpand)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: accent,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded && canExpand) ...[
          const SizedBox(height: 6),
          ...widget.children,
        ],
      ],
    );
  }
}

class _ShuttleRoutePinRow extends StatelessWidget {
  const _ShuttleRoutePinRow({
    required this.routeIndex,
    required this.stopCount,
    this.muted = false,
  });

  final int routeIndex;
  final int stopCount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final accent = muted
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : AppColors.primary;
    final soft = muted
        ? AppColors.background
        : AppColors.primaryLight.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: muted
              ? AppColors.searchBarBorder
              : AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_outlined, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '노선 $routeIndex · $stopCount곳',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExposureZoneRow extends StatelessWidget {
  const _ExposureZoneRow({
    required this.index,
    required this.point,
    this.muted = false,
  });

  final int index;
  final PushNotificationBasePoint point;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final label = ExposurePointLabels.compactLine(index, point);
    final accent = muted
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : AppColors.primary;
    final soft = muted
        ? AppColors.background
        : AppColors.primaryLight.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: muted
              ? AppColors.searchBarBorder
              : AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            index == 0 ? Icons.storefront_outlined : Icons.push_pin_outlined,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.post,
    required this.isClosed,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onClose,
    this.onCopy,
    this.onRepost,
    this.onManageExpansion,
    this.onReactivateWorkplace,
    this.onRecruit,
    this.shuttleOverlayBusy = false,
    this.extraPushAvailability,
  });

  final CorporateJobPost post;
  final bool isClosed;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClose;
  final VoidCallback? onCopy;
  final VoidCallback? onRepost;
  final VoidCallback? onManageExpansion;
  final VoidCallback? onReactivateWorkplace;
  final VoidCallback? onRecruit;
  final bool shuttleOverlayBusy;
  final ExtraPushAvailability? extraPushAvailability;

  @override
  Widget build(BuildContext context) {
    final canRecruit =
        !isClosed && (extraPushAvailability?.canDispatchRecruit ?? false);
    final workplaceExpired = post.isExpired;
    final exposurePoints = post.notificationSettings?.basePoints ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: '공고보기',
                icon: Icons.visibility_outlined,
                onPressed: onView,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: '공고수정',
                icon: Icons.edit_outlined,
                onPressed: onEdit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: '공고삭제',
                icon: Icons.delete_outline_rounded,
                onPressed: onDelete,
                destructive: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: '공고마감',
                icon: Icons.lock_outline_rounded,
                onPressed: onClose,
                done: isClosed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: '공고복사',
                icon: Icons.content_copy_outlined,
                onPressed: onCopy,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: '공고재등록',
                icon: Icons.replay_rounded,
                onPressed: onRepost,
              ),
            ),
          ],
        ),
        if (exposurePoints.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ExposureZoneRow(
            index: 0,
            point: exposurePoints.first,
            muted: isClosed,
          ),
          if (exposurePoints.length > 1) ...[
            const SizedBox(height: 6),
            _CollapsiblePinSection(
              title:
                  '${PushPackageCatalog.jobPinProductName}(${exposurePoints.length - 1})',
              icon: Icons.push_pin_outlined,
              muted: isClosed,
              children: [
                for (var i = 1; i < exposurePoints.length; i++) ...[
                  if (i > 1) const SizedBox(height: 6),
                  _ExposureZoneRow(
                    index: i,
                    point: exposurePoints[i],
                    muted: isClosed,
                  ),
                ],
              ],
            ),
          ],
        ],
        if (_showShuttlePinSection(post)) ...[
          SizedBox(height: exposurePoints.isNotEmpty ? 6 : 10),
          _CollapsiblePinSection(
            title:
                '${PushPackageCatalog.shuttlePinProductName}(${post.registeredShuttleStopCount})',
            icon: Icons.directions_bus_outlined,
            muted: isClosed,
            children: _shuttlePinExpandedRows(post, isClosed),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ServiceStatusTile(
                icon: Icons.storefront_outlined,
                label: workplaceExpired
                    ? JobPostExposureStatusLabels.workplaceInactive
                    : JobPostExposureStatusLabels.workplaceActive,
                active: !isClosed && !workplaceExpired,
                onTap: isClosed ? null : (workplaceExpired ? onReactivateWorkplace : null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ServiceStatusTile(
                icon: Icons.layers_outlined,
                label: JobPostExposureStatusLabels.shuttlePinCompact(post),
                active: !isClosed && _expansionActive,
                onTap: isClosed || shuttleOverlayBusy ? null : onManageExpansion,
                loading: shuttleOverlayBusy,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ServiceStatusTile(
                icon: Icons.send_rounded,
                label: '',
                active: canRecruit,
                emphasized: true,
                urgentPushLabel: true,
                onTap: canRecruit ? onRecruit : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool get _expansionActive {
    final hasShuttle = post.effectiveLinkedCommuteRouteIds.isNotEmpty;
    final extraPins = (post.notificationSettings?.basePoints.length ?? 0) > 1;
    return hasShuttle || extraPins || post.hasShuttleRouteOverlay;
  }

  static bool _showShuttlePinSection(CorporateJobPost post) {
    return post.registeredShuttleStopCount > 0 ||
        post.effectiveLinkedCommuteRouteIds.isNotEmpty;
  }

  static List<Widget> _shuttlePinExpandedRows(
    CorporateJobPost post,
    bool muted,
  ) {
    final linkedRoutes = post.effectiveLinkedCommuteRouteIds;
    final routeIds = linkedRoutes.isNotEmpty
        ? linkedRoutes
        : post.shuttleRegisteredStopIdsByRoute.keys.toList();

    return [
      for (var i = 0; i < routeIds.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        _ShuttleRoutePinRow(
          routeIndex: i + 1,
          stopCount:
              (post.shuttleRegisteredStopIdsByRoute[routeIds[i]] ?? const [])
                  .length,
          muted: muted,
        ),
      ],
    ];
  }
}

class _ServiceStatusTile extends StatelessWidget {
  const _ServiceStatusTile({
    required this.icon,
    required this.label,
    required this.active,
    this.emphasized = false,
    this.urgentPushLabel = false,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool emphasized;
  final bool urgentPushLabel;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final borderColor = emphasized && enabled
        ? AppColors.primary.withValues(alpha: 0.5)
        : active
            ? AppColors.primary.withValues(alpha: 0.28)
            : AppColors.searchBarBorder;
    final bg = emphasized && enabled
        ? AppColors.primaryLight.withValues(alpha: 0.14)
        : active
            ? AppColors.primaryLight.withValues(alpha: 0.1)
            : AppColors.background;
    final fg = enabled
        ? (emphasized ? AppColors.primary : AppColors.textPrimary)
        : AppColors.textSecondary.withValues(alpha: 0.55);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              else if (urgentPushLabel) ...[
                const UrgentHireBadge(height: 16, fontSize: 9.5),
                const SizedBox(height: 6),
                Text(
                  '알림 보내기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ]
              else
                Icon(icon, size: 20, color: fg),
              if (!urgentPushLabel) ...[
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.emphasized = false,
    this.actionable = false,
    this.done = false,
    this.fullWidth = false,
    this.loading = false,
    this.costLabel,
    this.urgentPushLabel = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool emphasized;
  final bool actionable;
  final bool done;
  final bool fullWidth;
  final bool loading;
  final String? costLabel;
  final bool urgentPushLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final foreground = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : destructive
            ? const Color(0xFFC62828)
            : done
                ? const Color(0xFF2E7D32)
                : emphasized
                    ? AppColors.primary
                    : actionable
                        ? AppColors.primary
                        : AppColors.textPrimary;

    final button = OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(
          color: enabled
              ? (emphasized
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : done
                      ? const Color(0xFFA5D6A7)
                      : actionable
                          ? AppColors.primary.withValues(alpha: 0.45)
                          : AppColors.searchBarBorder)
              : AppColors.searchBarBorder.withValues(alpha: 0.6),
          width: emphasized && enabled ? 1.5 : 1,
        ),
        padding: EdgeInsets.symmetric(
          vertical: fullWidth ? 14 : 12,
          horizontal: 4,
        ),
        minimumSize: Size(fullWidth ? double.infinity : 0, fullWidth ? 56 : 52),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: emphasized && enabled
            ? AppColors.primaryLight.withValues(alpha: 0.12)
            : done
                ? const Color(0xFFE8F5E9)
                : null,
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: fullWidth ? 20 : 18, color: foreground),
                const SizedBox(height: 2),
                if (urgentPushLabel)
                  UrgentPushActionLabel(
                    compact: true,
                    textColor: foreground,
                    fontSize: fullWidth ? 11 : 10,
                  )
                else
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fullWidth ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (costLabel != null && enabled) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: emphasized
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      costLabel!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: emphasized
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
    this.muted = false,
    this.onTap,
  });

  static const _activeBg = Color(0xFFF3EEFF);
  static const _activeBorder = Color(0xFFD4C4FF);

  final IconData icon;
  final String label;
  final bool highlighted;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? AppColors.background
            : highlighted
                ? _activeBg
                : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: muted
            ? Border.all(color: AppColors.searchBarBorder.withValues(alpha: 0.6))
            : highlighted
                ? Border.all(color: _activeBorder)
                : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: muted
                ? AppColors.textSecondary.withValues(alpha: 0.45)
                : highlighted
                    ? AppColors.primary
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: muted
                    ? AppColors.textSecondary.withValues(alpha: 0.45)
                    : highlighted
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.95),
              ),
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
