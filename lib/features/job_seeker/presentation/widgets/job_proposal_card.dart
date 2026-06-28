import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/hiring/domain/entities/job_proposal.dart';

class JobProposalCard extends StatelessWidget {
  const JobProposalCard({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onDecline,
  });

  final JobProposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  static final _dateFormat = DateFormat('M월 d일');

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '채용 제안',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _dateFormat.format(proposal.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            proposal.companyName,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            proposal.postTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (proposal.message != null && proposal.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              proposal.message!,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('수락·지원'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
