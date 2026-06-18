import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';
import 'package:map/features/corporate/domain/services/seeker_profile_lookup.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 구인자 — 지원자 이력서 (근태 그리드·지원자 탭 공통)
class CorporateApplicantResumePage extends StatefulWidget {
  const CorporateApplicantResumePage({
    super.key,
    required this.applicationId,
  });

  final String applicationId;

  @override
  State<CorporateApplicantResumePage> createState() =>
      _CorporateApplicantResumePageState();
}

Future<void> openCorporateApplicantResume(
  BuildContext context, {
  required String applicationId,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CorporateApplicantResumePage(
        applicationId: applicationId,
      ),
    ),
  );
}

class _CorporateApplicantResumePageState
    extends State<CorporateApplicantResumePage> {
  HiringApplication? _application;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await LocalHiringRepository.create();
    final app = await repo.findById(widget.applicationId);
    if (app == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _application = app;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('지원자 이력서'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _application == null
              ? _NotFound(onBack: () => Navigator.of(context).pop())
              : _ResumeBody(application: _application!),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('지원 정보를 찾을 수 없습니다.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onBack, child: const Text('돌아가기')),
        ],
      ),
    );
  }
}

class _ResumeBody extends StatelessWidget {
  const _ResumeBody({required this.application});

  final HiringApplication application;

  @override
  Widget build(BuildContext context) {
    final seekerProfile = SeekerProfileLookup.forEmail(application.seekerEmail);
    final status = _mapStatus(application.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: status),
                  const Spacer(),
                  Text(
                    LocalHiringRepository.formatRelativeTime(
                      application.appliedAt,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                application.seekerName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('기본 정보'),
              _InfoRow(label: '성별', value: seekerProfile.genderLabel),
              _InfoRow(label: '생년월일', value: seekerProfile.birthDateLabel),
              _InfoRow(
                label: '연락처',
                value: application.seekerPhoneMasked,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('지원 정보'),
              _InfoRow(
                icon: Icons.work_outline_rounded,
                label: '공고',
                value: application.postTitle,
              ),
              if (application.workDate != null)
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: '근무 예정',
                  value: LocalHiringRepository.formatWorkDateFull(
                    application.workDate!,
                  ),
                ),
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: '근무 시간',
                value: application.workSchedule,
              ),
              _InfoRow(
                icon: Icons.business_outlined,
                label: '기업',
                value: application.companyName,
              ),
            ],
          ),
        ),
        if (seekerProfile.experienceSummary != null &&
            seekerProfile.experienceSummary!.isNotEmpty) ...[
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('경력·자기소개'),
                Text(
                  seekerProfile.experienceSummary!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textSecondary.withValues(alpha: 0.98),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (seekerProfile.preferredJobCategories.isNotEmpty) ...[
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('희망 업무'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: seekerProfile.preferredJobCategories
                      .map(
                        (c) => Chip(
                          label: Text(c),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  CorporateApplicantStatus _mapStatus(HiringApplicationStatus status) =>
      switch (status) {
        HiringApplicationStatus.applied => CorporateApplicantStatus.pending,
        HiringApplicationStatus.chatting => CorporateApplicantStatus.chatting,
        HiringApplicationStatus.scheduled => CorporateApplicantStatus.scheduled,
        HiringApplicationStatus.checkedIn => CorporateApplicantStatus.checkedIn,
        HiringApplicationStatus.commissionPaid =>
          CorporateApplicantStatus.commissionPaid,
        HiringApplicationStatus.rejected => CorporateApplicantStatus.rejected,
        HiringApplicationStatus.noShow => CorporateApplicantStatus.rejected,
      };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
