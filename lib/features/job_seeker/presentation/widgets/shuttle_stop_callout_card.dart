import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/job_seeker/domain/entities/map_callout_item.dart';

/// 스와이프 캐러셀 — 정류장핀 카드 (JobMapPinCalloutCard와 동일한 규격)
class ShuttleStopCalloutCard extends StatelessWidget {
  const ShuttleStopCalloutCard({
    super.key,
    required this.item,
    required this.onClose,
    required this.onViewLinkedJob,
  });

  final ShuttleStopCalloutItem item;
  final VoidCallback onClose;
  final VoidCallback onViewLinkedJob;

  @override
  Widget build(BuildContext context) {
    final stop = item.stop;
    final route = item.route;
    final timeLabel = stop.departureTime;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stop.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              route.routeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            if (timeLabel != null && timeLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '탑승 시각 $timeLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onViewLinkedJob,
                child: const Text('이 정류장을 이용하는 공고 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
