import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/guest_browse_intent.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';
import 'package:map/features/corporate/presentation/utils/corporate_shell_access.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_bottom_nav.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_guest_auth_actions.dart';

enum CorporateNavSection {
  home('홈', Icons.home_rounded),
  jobPosts('공고', Icons.article_outlined),
  applicants('지원자', Icons.people_outline_rounded),
  attendance('근태', Icons.schedule_outlined),
  chat('채팅', Icons.chat_bubble_outline_rounded),
  more('더보기', Icons.more_horiz_rounded);

  const CorporateNavSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 기업회원 — 넓은 웹: **우측** 레일 · 모바일: 하단 탭
class CorporateWebScaffold extends StatelessWidget {
  const CorporateWebScaffold({
    super.key,
    required this.sectionIndex,
    required this.onSectionChanged,
    required this.body,
    this.actions,
    this.isItemEnabled,
  });

  final int sectionIndex;
  final ValueChanged<int> onSectionChanged;
  final Widget body;
  final List<Widget>? actions;
  final bool Function(int index)? isItemEnabled;

  @override
  Widget build(BuildContext context) {
    final wide = WebLayoutBreakpoints.isWideWeb(context);
    final title = corporateShellTitleForSession();
    final guest = !CorporateShellAccess.isSignedInCorporate;

    if (wide) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    title: title,
                    subtitle: guest ? '채용 지도를 먼저 둘러보세요' : null,
                    actions: actions,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
            WebRightNavigationRail(
              items: CorporateBottomNav.entries,
              currentIndex: sectionIndex,
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
                      '기업',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              footer: guest
                  ? const CorporateGuestAuthActions(
                      layout: CorporateGuestAuthLayout.rail,
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton(
                        tooltip: '구직자 홈',
                        onPressed: () {
                          GuestBrowseIntent.useSeeker();
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.home,
                            (_) => false,
                          );
                        },
                        icon: Icon(
                          Icons.home_outlined,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
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
        actions: [
          if (guest)
            const CorporateGuestAuthActions(
              layout: CorporateGuestAuthLayout.appBar,
            )
          else
            ...?actions,
        ],
      ),
      body: body,
      bottomNavigationBar: CorporateBottomNav(
        currentIndex: sectionIndex,
        onTap: onSectionChanged,
        isItemEnabled: isItemEnabled,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final guest = !CorporateShellAccess.isSignedInCorporate;

    return Material(
      color: AppColors.surface,
      elevation: 0,
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
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (guest)
                const CorporateGuestAuthActions(
                  layout: CorporateGuestAuthLayout.topBar,
                )
              else
                ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}
