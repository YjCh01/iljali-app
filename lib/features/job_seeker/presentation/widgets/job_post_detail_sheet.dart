import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';
import 'package:map/core/trust/presentation/employer_trust_section.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 지도 핀 탭 시 공고 상세 바텀시트
class JobPostDetailSheet extends StatelessWidget {
  const JobPostDetailSheet({
    super.key,
    required this.pin,
    required this.onClose,
    required this.onApply,
  });

  final JobMapPin pin;
  final VoidCallback onClose;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final post = pin.post;
    final payDay = post.paymentScheduleDisplayLabel ?? '협의';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x337C5CFC),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pin.companyName,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 8),
                          EmployerTrustSection(
                            companyKey: post.registeredBy?.companyKey,
                            profile: post.registeredBy,
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: post.status),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    post.fullDescriptionText,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: '근무지', value: post.warehouseName),
                const SizedBox(height: 8),
                _InfoRow(label: '고용 형태', value: post.employmentType.label),
                const SizedBox(height: 8),
                _InfoRow(label: '시급', value: post.hourlyWage),
                if (post.dailyWage != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: '일급', value: post.dailyWage!),
                ],
                const SizedBox(height: 8),
                _InfoRow(label: '근무 일정', value: post.workSchedule),
                const SizedBox(height: 8),
                _InfoRow(label: '급여지급일', value: payDay),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.primaryLight.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '닫기',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onApply,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '지원하기',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CorporateJobPostStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> showJobApplyDialog(
  BuildContext context,
  JobMapPin pin, {
  VoidCallback? onApplied,
}) async {
  final user = AuthSession.instance.currentUser;
  final repo = await JobApplicationRepository.create(user?.email);
  final hiringRepo = await LocalHiringRepository.create();

  if (user != null &&
      !await ensureSeekerAttendanceAccess(context, user.email)) {
    return false;
  }
  if (!context.mounted) return false;

  if (user != null &&
      await hiringRepo.hasApplied(pin.post.id, user.email)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미 「${pin.post.title}」에 지원하셨습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('지원 확인'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pin.post.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(pin.companyName),
          if (pin.post.registeredBy != null) ...[
            const SizedBox(height: 10),
            EmployerTrustSection(
              companyKey: pin.post.registeredBy!.companyKey,
              profile: pin.post.registeredBy,
              compact: true,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            employmentTypeLabel(pin.post.employmentType),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            '채팅 후 출근 확정 뒤 무통보 노쇼 시\n서비스 이용이 제한될 수 있습니다.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          if (user != null) ...[
            const SizedBox(height: 12),
            Text('지원자: ${user.name}'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('지원하기'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted && user != null) {
    final phone = user.phone ?? '010-0000-0000';
    final masked = phone.length >= 4
        ? '${phone.substring(0, phone.length - 4)}****'
        : phone;

    await hiringRepo.submitApplication(
      postId: pin.post.id,
      postTitle: pin.post.title,
      companyName: pin.companyName,
      companyKey: pin.post.registeredBy?.companyKey,
      branchId: pin.post.branchId,
      branchName: pin.post.branchName,
      workplaceLatitude: pin.latitude != 0 ? pin.latitude : null,
      workplaceLongitude: pin.longitude != 0 ? pin.longitude : null,
      seekerEmail: user.email,
      seekerName: user.name,
      seekerPhoneMasked: masked,
      workSchedule: pin.post.workSchedule,
      suggestedWorkDate: pin.post.paymentDate,
      hourlyWageText: pin.post.hourlyWage,
      employmentType: pin.post.employmentType,
    );

    if (repo != null) {
      await repo.add(
        JobApplication(
          postId: pin.post.id,
          title: pin.post.title,
          company: pin.companyName,
          appliedAt: DateTime.now(),
          status: HiringApplicationStatus.applied.label,
          companyKey: pin.post.registeredBy?.companyKey,
        ),
      );
    }
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('「${pin.post.title}」 지원이 접수되었습니다.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '내 지원',
            onPressed: onApplied ?? () {},
          ),
        ),
      );
    onApplied?.call();
    return true;
  }
  return false;
}

String employmentTypeLabel(JobEmploymentType type) {
  return switch (type) {
    JobEmploymentType.daily =>
      '일용직 — 출근 확인 시 ${AppStrings.dailyCommissionNote}',
    JobEmploymentType.permanent =>
      '상시직 — ${AppStrings.permanentCommissionNote}',
  };
}
