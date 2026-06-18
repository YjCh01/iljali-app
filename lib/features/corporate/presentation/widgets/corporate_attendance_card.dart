import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

class CorporateAttendanceCard extends StatelessWidget {
  const CorporateAttendanceCard({
    super.key,
    required this.record,
    this.onTap,
    this.onEmployerConfirm,
    this.onMarkNoShow,
  });

  final CorporateAttendanceRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onEmployerConfirm;
  final VoidCallback? onMarkNoShow;

  @override
  Widget build(BuildContext context) {
    final coach = _AttendanceCoach.fromRecord(record);

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
          if (record.workAgreementComplete) ...[
            const SizedBox(height: 8),
            Text(
              record.countdownLabel != null
                  ? '출근까지 ${record.countdownLabel}'
                  : '근무예정 합의 완료',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: record.countdownLabel != null
                    ? AppColors.primary.withValues(alpha: 0.95)
                    : AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: '출근',
                  time: record.checkInLabel,
                ),
              ),
            ],
          ),
          if (coach != null) ...[
            const SizedBox(height: 12),
            _AttendanceCoachBubble(
              title: coach.title,
              message: coach.message,
            ),
          ],
          if (record.canMarkNoShow || coach?.showConfirmButton == true) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (record.canMarkNoShow)
                  OutlinedButton(
                    onPressed: onMarkNoShow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFE57373)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('노쇼'),
                  ),
                const Spacer(),
                if (coach?.showConfirmButton == true)
                  FilledButton(
                    onPressed: coach!.confirmEnabled
                        ? (onEmployerConfirm ?? onTap)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '출근 확정',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (ProductFeatureFlags.isHiringCommissionEnabled &&
              record.needsCommissionPayment &&
              record.commissionAmountKrw != null) ...[
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
          if (ProductFeatureFlags.isHiringCommissionEnabled &&
              record.escalationLevel >= 2) ...[
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

class _AttendanceCoach {
  const _AttendanceCoach({
    required this.title,
    required this.message,
    required this.showConfirmButton,
    required this.confirmEnabled,
  });

  final String title;
  final String message;
  final bool showConfirmButton;
  final bool confirmEnabled;

  static _AttendanceCoach? fromRecord(CorporateAttendanceRecord record) {
    if (record.awaitingEmployerConfirm) {
      return const _AttendanceCoach(
        title: '출근 체크 완료',
        message: '현장(근무지 200m 이내)에서 출근 확정을 눌러주세요.',
        showConfirmButton: true,
        confirmEnabled: true,
      );
    }
    if (record.awaitingSeekerCheckIn) {
      return const _AttendanceCoach(
        title: '출근 확정 완료',
        message: '구직자 출근 체크를 기다리는 중입니다.',
        showConfirmButton: false,
        confirmEnabled: false,
      );
    }
    if (record.canEmployerConfirm) {
      return const _AttendanceCoach(
        title: '아직 출근 전',
        message: '지원자가 현장에서 출근 확인하면 출근 확정을 눌러주세요.',
        showConfirmButton: true,
        confirmEnabled: false,
      );
    }
    return null;
  }
}

class _AttendanceCoachBubble extends StatelessWidget {
  const _AttendanceCoachBubble({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary.withValues(alpha: 0.98),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 28,
          bottom: -7,
          child: CustomPaint(
            size: const Size(14, 8),
            painter: _BubbleTailPainter(
              color: AppColors.primaryLight.withValues(alpha: 0.14),
              borderColor: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
