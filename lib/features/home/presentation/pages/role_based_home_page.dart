import 'package:flutter/material.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/guest_browse_intent.dart';
import 'package:map/features/corporate/presentation/pages/corporate_home_shell_page.dart';
import 'package:map/features/job_seeker/presentation/pages/individual_home_shell_page.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_my_jobs_tab.dart';

/// 로그인 후 회원 유형별 홈 분기 · 비로그인은 둘러보기 모드별 셸
class RoleBasedHomePage extends StatelessWidget {
  const RoleBasedHomePage({
    super.key,
    this.initialSeekerTabIndex = 0,
    this.initialSeekerMyJobsSegment = 0,
  });

  final int initialSeekerTabIndex;
  final int initialSeekerMyJobsSegment;

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;

    if (user == null) {
      if (GuestBrowseIntent.mode == GuestBrowseMode.corporate) {
        return const CorporateHomeShellPage();
      }
      return IndividualHomeShellPage(
        initialTabIndex: normalizeSeekerTabIndex(initialSeekerTabIndex),
        initialMyJobsSegment: initialSeekerMyJobsSegment,
      );
    }

    if (user.isCorporate) {
      return const CorporateHomeShellPage();
    }

    return IndividualHomeShellPage(
      initialTabIndex: normalizeSeekerTabIndex(initialSeekerTabIndex),
      initialMyJobsSegment: initialSeekerMyJobsSegment,
    );
  }
}
