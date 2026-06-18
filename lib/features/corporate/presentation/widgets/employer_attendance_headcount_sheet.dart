import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';

/// 기업 근태 — 근무 중 인원 · 일용직/그 외 분류
Future<void> showEmployerAttendanceHeadcountSheet(
  BuildContext context, {
  required List<CorporateAttendanceRecord> todayRecords,
}) {
  final onDuty = todayRecords
      .where(
        (r) =>
            r.rollCallStatus == TodayRollCallStatus.present ||
            r.rollCallStatus == TodayRollCallStatus.pending,
      )
      .toList();
  final dailyCount = onDuty.where((r) => r.isDailyWorker).length;
  final otherCount = onDuty.length - dailyCount;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '오늘 근무 ${onDuty.length}명',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _CountRow(label: '일용직', count: dailyCount),
            const SizedBox(height: 10),
            _CountRow(label: '그 외', count: otherCount),
            const SizedBox(height: 16),
            Text(
              '달력 필터에서 일용직만 보거나 전체 인원을 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EmployerAttendanceHeadcountBanner extends StatelessWidget {
  const EmployerAttendanceHeadcountBanner({
    super.key,
    required this.count,
    required this.dailyCount,
    required this.otherCount,
    required this.onTap,
  });

  final int count;
  final int dailyCount;
  final int otherCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '근무 중 $count명',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '일용직 $dailyCount명 · 그 외 $otherCount명',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$count명',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
