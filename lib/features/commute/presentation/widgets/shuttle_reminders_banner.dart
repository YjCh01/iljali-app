import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/services/shuttle_reminder_service.dart';

/// 내 지원 상단 — 셔틀 알림 배너 (MVP)
class ShuttleRemindersBanner extends StatelessWidget {
  const ShuttleRemindersBanner({
    super.key,
    required this.reminders,
    required this.onDismiss,
  });

  final List<ShuttleReminder> reminders;
  final void Function(ShuttleReminder) onDismiss;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    final reminder = reminders.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.body,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onDismiss(reminder),
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
