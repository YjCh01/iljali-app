import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_snapshot.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_resume_detail_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_resume_grid_summary.dart';

/// 구직자 — 내 이력서 (그리드 요약 + 상세보기)
class SeekerMyResumePage extends StatefulWidget {
  const SeekerMyResumePage({super.key});

  @override
  State<SeekerMyResumePage> createState() => _SeekerMyResumePageState();
}

class _SeekerMyResumePageState extends State<SeekerMyResumePage> {
  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    if (user == null || user.memberType != MemberType.individual) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: const AppBackButton(),
          title: const Text('내 이력서'),
        ),
        body: const Center(child: Text('로그인 후 이력서를 확인할 수 있습니다.')),
      );
    }

    final profile = user.seekerProfile;
    final complete = profile?.isOnboardingComplete ?? false;
    final snapshot = SeekerResumeSnapshot.fromAuthUser(user);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('내 이력서'),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.of(context).pushNamed(AppRoutes.seekerResumeEdit);
              if (mounted) setState(() {});
            },
            child: const Text('작성·수정'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (!complete)
            CorporateSurfaceCard(
              child: Text(
                '이력서를 작성하면 기업에게 제안·지원 시 신뢰도가 높아집니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
          if (!complete) const SizedBox(height: 12),
          SeekerResumeGridSummary(
            snapshot: snapshot,
            subtitle: user.email.isNotEmpty ? user.email : null,
            resumeCounts: ResumeItemKind.values
                .map((k) =>
                    profile?.countForResumeKind(k) ??
                    snapshot.resume.countFor(k))
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => openSeekerResumeDetail(
                context,
                snapshot: snapshot,
                title: '내 이력서 상세',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '상세보기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
