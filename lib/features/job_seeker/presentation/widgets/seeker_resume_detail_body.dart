import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/corporate/presentation/widgets/employer_credential_section.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_snapshot.dart';

/// 이력서 전체 상세 본문
class SeekerResumeDetailBody extends StatelessWidget {
  const SeekerResumeDetailBody({
    super.key,
    required this.snapshot,
    this.showContact = true,
  });

  final SeekerResumeSnapshot snapshot;
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    final app = snapshot.application;
    final resume = snapshot.visibleResume;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (snapshot.email != null) ...[
                const SizedBox(height: 4),
                Text(
                  snapshot.email!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('기본 정보'),
              _InfoRow(label: '성별', value: snapshot.genderLabel),
              _InfoRow(label: '나이', value: snapshot.ageLabel),
              _InfoRow(label: '생년월일', value: snapshot.birthDateLabel),
              if (snapshot.nationalityLabel != null)
                _InfoRow(label: '국적', value: snapshot.nationalityLabel!),
              if (showContact && snapshot.phoneMasked != null)
                _InfoRow(label: '연락처', value: snapshot.phoneMasked!),
            ],
          ),
        ),
        if (app != null) ...[
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('지원 정보'),
                _InfoRow(
                  icon: Icons.work_outline_rounded,
                  label: '공고',
                  value: app.postTitle,
                ),
                if (app.workDateLabel != null)
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: '근무 예정',
                    value: app.workDateLabel!,
                  ),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: '근무 시간',
                  value: app.workSchedule,
                ),
                _InfoRow(
                  icon: Icons.business_outlined,
                  label: '기업',
                  value: app.companyName,
                ),
              ],
            ),
          ),
        ],
        if (snapshot.preferredRegions.isNotEmpty) ...[
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('희망 근무 지역'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: snapshot.preferredRegions
                      .map((r) => Chip(label: Text(r)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        if (snapshot.preferredJobCategories.isNotEmpty) ...[
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('희망 업무'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: snapshot.preferredJobCategories
                      .map((c) => Chip(label: Text(c)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
        if (snapshot.credentials.isNotEmpty) ...[
          const SizedBox(height: 12),
          EmployerCredentialSection(
            credentials: snapshot.credentials,
            canViewDocuments: snapshot.canViewCredentialDocuments,
            requiredOnly: snapshot.credentialsArePostRequirements,
          ),
        ],
        if (_hasResumeSections(resume)) ...[
          const SizedBox(height: 12),
          ..._resumeSections(resume),
        ] else if (snapshot.experienceSummary != null &&
            snapshot.experienceSummary!.isNotEmpty) ...[
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('경력·자기소개'),
                Text(
                  snapshot.experienceSummary!,
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
      ],
    );
  }

  bool _hasResumeSections(SeekerResumeContent resume) {
    return resume.educations.isNotEmpty ||
        resume.experiences.isNotEmpty ||
        resume.selfIntroduction.trim().isNotEmpty;
  }

  List<Widget> _resumeSections(SeekerResumeContent resume) {
    final sections = <Widget>[];

    void addSection(String title, List<Widget> children) {
      if (children.isEmpty) return;
      sections.add(
        CorporateSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title),
              ...children,
            ],
          ),
        ),
      );
      sections.add(const SizedBox(height: 12));
    }

    addSection(
      ResumeItemKind.education.label,
      resume.educations
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                e.summaryLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          )
          .toList(),
    );

    addSection(
      ResumeItemKind.experience.label,
      resume.experiences.map((e) {
        final period = e.periodLabel;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.summaryLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (period != null) ...[
                const SizedBox(height: 2),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
              if (e.description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  e.description!.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );

    if (resume.selfIntroduction.trim().isNotEmpty) {
      addSection(
        ResumeItemKind.selfIntroduction.label,
        [
          Text(
            resume.selfIntroduction.trim(),
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textSecondary.withValues(alpha: 0.98),
            ),
          ),
        ],
      );
    }

    if (sections.isNotEmpty && sections.last is SizedBox) {
      sections.removeLast();
    }
    return sections;
  }
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
