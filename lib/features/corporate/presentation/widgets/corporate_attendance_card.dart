import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class CorporateAttendanceCard extends StatelessWidget {
  const CorporateAttendanceCard({
    super.key,
    required this.record,
    this.onTap,
    this.onEmployerConfirm,
  });

  final CorporateAttendanceRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onEmployerConfirm;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: record.status),
              const Spacer(),
              Text(
                record.workDateLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            record.workerName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _Line(icon: Icons.work_outline_rounded, text: record.jobTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: '출근',
                  time: record.checkInLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBox(
                  label: '퇴근',
                  time: record.checkOutLabel,
                ),
              ),
            ],
          ),
          if (record.awaitingEmployerConfirm) ...[
            const SizedBox(height: 8),
            Text(
              '구직자 출근 체크 완료 · 기업 확인이 필요합니다',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.95),
              ),
            ),
          ],
          if (record.awaitingSeekerCheckIn) ...[
            const SizedBox(height: 8),
            Text(
              '기업 출근 확인 완료 · 구직자 출근 체크 대기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
          if (record.canEmployerConfirm) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onEmployerConfirm ?? onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                record.awaitingEmployerConfirm ? '출근 확인' : '출근 확인 (구직자 대기)',
              ),
            ),
          ],
          if (record.needsCommissionPayment && record.commissionAmountKrw != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                '수수료 ${record.commissionAmountKrw.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원 결제',
              ),
            ),
          ],
          if (record.escalationLevel >= 2) ...[
            const SizedBox(height: 8),
            Text(
              record.escalationLevel >= 3
                  ? '고객센터 ARS 자동 연락 발송됨'
                  : '수수료 결제 지연 알림 ${record.escalationLevel}회',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC62828),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CorporateAttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CorporateAttendanceStatus.onTime => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
        ),
      CorporateAttendanceStatus.late => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      CorporateAttendanceStatus.earlyLeave => (
          AppColors.primaryLight.withValues(alpha: 0.28),
          AppColors.primary,
        ),
      CorporateAttendanceStatus.absent => (
          AppColors.background,
          AppColors.textSecondary,
        ),
      CorporateAttendanceStatus.pendingCommission => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
        ),
      CorporateAttendanceStatus.awaitingEmployerConfirm => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
        ),
      CorporateAttendanceStatus.awaitingSeekerCheckIn => (
          AppColors.primaryLight.withValues(alpha: 0.28),
          AppColors.primary,
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

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.time,
  });

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
