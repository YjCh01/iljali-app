import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_transport_widgets.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 클러스터(핀 뭉치) 탭 — 랭킹된 공고 목록
class JobMapClusterListSheet extends StatelessWidget {
  const JobMapClusterListSheet({
    super.key,
    required this.pins,
    required this.onClose,
    required this.onPinSelected,
  });

  final List<JobMapPin> pins;
  final VoidCallback onClose;
  final ValueChanged<JobMapPin> onPinSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x337C5CFC),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '근처 공고 ${pins.length}건',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '지원·신선도·알림핀·셔틀·거리 순으로 정렬',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: pins.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final pin = pins[index];
                    return _ClusterPinRow(
                      pin: pin,
                      rank: index + 1,
                      onTap: () => onPinSelected(pin),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClusterPinRow extends StatelessWidget {
  const _ClusterPinRow({
    required this.pin,
    required this.rank,
    required this.onTap,
  });

  final JobMapPin pin;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = pin.displayTier;
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tier.pinColor,
                  border: Border.all(color: tier.pinBorderColor, width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pin.post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (pin.post.showsShuttleRouteOverlay) ...[
                          const SizedBox(width: 6),
                          const ShuttleListTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pin.companyName} · ${pin.post.hourlyWage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              if (tier != JobMapPinDisplayTier.standard) ...[
                const SizedBox(width: 6),
                Text(
                  tier.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: tier.pinColor,
                  ),
                ),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
