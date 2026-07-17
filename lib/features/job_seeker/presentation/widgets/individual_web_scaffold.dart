import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';
import 'package:map/features/job_seeker/presentation/widgets/individual_bottom_nav.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_guest_auth_actions.dart';

/// 구직자 — 넓은 웹: 우측 레일 · 모바일/앱: 하단 탭
class IndividualWebScaffold extends StatelessWidget {
  const IndividualWebScaffold({
    super.key,
    required this.currentIndex,
    required this.onSectionChanged,
    required this.body,
    this.isItemEnabled,
    this.myJobsBadgeCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onSectionChanged;
  final Widget body;
  final bool Function(int index)? isItemEnabled;
  final int myJobsBadgeCount;

  @override
  Widget build(BuildContext context) {
    final wide = WebLayoutBreakpoints.isWideWeb(context);
    final title = seekerShellTitleForSession();
    final guest = !SeekerShellAccess.isSignedInSeeker;

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    title: title,
                    subtitle: guest ? '지도에서 일자리를 먼저 둘러보세요' : null,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
            WebRightNavigationRail(
              items: IndividualBottomNav.buildEntries(
                myJobsBadgeCount: myJobsBadgeCount,
              ),
              currentIndex: currentIndex,
              onTap: onSectionChanged,
              isItemEnabled: isItemEnabled,
              header: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Text(
                      '일자리',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '구직',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              footer: guest
                  ? const SeekerGuestAuthActions(
                      layout: SeekerGuestAuthLayout.rail,
                    )
                  : null,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const AppRootLeading(),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: guest
            ? const [
                SeekerGuestAuthActions(layout: SeekerGuestAuthLayout.appBar),
              ]
            : null,
      ),
      body: body,
      bottomNavigationBar: IndividualBottomNav(
        currentIndex: currentIndex,
        onTap: onSectionChanged,
        isItemEnabled: isItemEnabled,
        myJobsBadgeCount: myJobsBadgeCount,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final guest = !SeekerShellAccess.isSignedInSeeker;

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (guest)
                const SeekerGuestAuthActions(
                  layout: SeekerGuestAuthLayout.topBar,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
