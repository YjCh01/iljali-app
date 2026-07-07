import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 어드민 — 이용권·핀 부여 수량 (+/−, 1개 단위)
class AdminCreditStepper extends StatelessWidget {
  const AdminCreditStepper({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
  });

  final String label;
  final String subtitle;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  void _decrement() {
    if (value <= min) return;
    onChanged(value - 1);
  }

  void _increment() {
    if (value >= max) return;
    onChanged(value + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value <= min ? null : _decrement,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: '1개 줄이기',
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : _increment,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '1개 늘리기',
          ),
        ],
      ),
    );
  }
}
