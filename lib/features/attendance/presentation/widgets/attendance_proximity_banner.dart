import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/attendance_proximity_service.dart';

/// 근무지 300m 이내 — 출근 체크 활성화 안내 배너
class AttendanceProximityBanner extends StatelessWidget {
  const AttendanceProximityBanner({
    super.key,
    required this.result,
    required this.onCheckIn,
    this.companyLabel,
  });

  final AttendanceProximityResult result;
  final VoidCallback onCheckIn;
  final String? companyLabel;

  @override
  Widget build(BuildContext context) {
    if (!result.shouldPrompt && !result.relaxed) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onCheckIn,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppColors.primary.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '출근 체크 활성화',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      companyLabel != null
                          ? '$companyLabel · ${result.bannerMessage}'
                          : result.bannerMessage,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  '출근',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
