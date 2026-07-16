import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class CorporateApplicantCard extends StatelessWidget {
  const CorporateApplicantCard({
    super.key,
    required this.applicant,
    this.isNew = false,
    this.onTap,
    this.onChat,
    this.onInstantAccept,
  });

  final CorporateApplicant applicant;
  final bool isNew;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onInstantAccept;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isNew) ...[
                const _NewBadge(),
                const SizedBox(width: 6),
              ],
              _StatusBadge(status: applicant.status),
              if (applicant.noShowCount > 0) ...[
                const SizedBox(width: 6),
                _NoShowBadge(count: applicant.noShowCount),
              ],
              const Spacer(),
              Text(
                applicant.appliedAtLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            applicant.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _Line(icon: Icons.work_outline_rounded, text: applicant.jobTitle),
          const SizedBox(height: 6),
          _Line(icon: Icons.phone_outlined, text: applicant.phoneMasked),
          if (applicant.workDateLabel != null) ...[
            const SizedBox(height: 6),
            _Line(
              icon: Icons.event_outlined,
              text: '출근 예정 ${applicant.workDateLabel}',
            ),
          ],
          if (onChat != null || onInstantAccept != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onChat != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('채팅'),
                    ),
                  ),
                if (onChat != null && onInstantAccept != null)
                  const SizedBox(width: 8),
                if (onInstantAccept != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onInstantAccept,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('즉시 확정'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CorporateApplicantStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CorporateApplicantStatus.pending => (
          AppColors.primaryLight.withValues(alpha: 0.28),
          AppColors.primary,
        ),
      CorporateApplicantStatus.chatting => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
        ),
      CorporateApplicantStatus.scheduled => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
        ),
      CorporateApplicantStatus.checkedIn => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      CorporateApplicantStatus.commissionPaid => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
        ),
      CorporateApplicantStatus.rejected => (
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

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _NoShowBadge extends StatelessWidget {
  const _NoShowBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '노쇼 $count회',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFC62828),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
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
