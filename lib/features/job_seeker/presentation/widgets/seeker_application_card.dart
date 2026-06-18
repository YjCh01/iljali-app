import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/trust/presentation/employer_trust_section.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';

class SeekerApplicationCard extends StatelessWidget {
  const SeekerApplicationCard({
    super.key,
    required this.item,
    required this.dateFormat,
    this.onTap,
    this.subtitle,
    this.shuttleReminder,
  });

  final JobApplication item;
  final DateFormat dateFormat;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? shuttleReminder;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.company,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          if (shuttleReminder != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shuttleReminder!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (item.companyKey != null) ...[
            const SizedBox(height: 8),
            EmployerTrustSection(
              companyKey: item.companyKey,
              compact: true,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusChip(label: item.status),
              const Spacer(),
              Text(
                '지원일 ${dateFormat.format(item.appliedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
