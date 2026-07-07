import 'package:flutter/material.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/core/session/auth_session.dart';
import 'package:map/core/sync/member_sanction_guard.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_chat_tab.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_map_tab.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_more_tab.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_my_jobs_tab.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_vault_tab.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';
import 'package:map/features/job_seeker/presentation/widgets/individual_web_scaffold.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_login_prompt_sheet.dart';

/// 구직자 메인 셸 — 지도에서 공고 탐색 · 보관함에 저장
class IndividualHomeShellPage extends StatefulWidget {
  const IndividualHomeShellPage({
    super.key,
    this.initialTabIndex = 0,
    this.initialMyJobsSegment = 0,
  });

  final int initialTabIndex;
  final int initialMyJobsSegment;

  @override
  State<IndividualHomeShellPage> createState() =>
      _IndividualHomeShellPageState();
}

class _IndividualHomeShellPageState extends State<IndividualHomeShellPage> {
  late int _currentIndex;

  int _reloadToken = 0;

  int _applicationsRevision = 0;
  int _workRevision = 0;

  int _myJobsSegment = 0;

  void _switchTab(int index) {
    if (!SeekerShellAccess.isTabEnabled(index)) {
      SeekerLoginPromptSheet.show(context);
      return;
    }

    setState(() {
      _currentIndex = index;

      if (index == 0 || index == 1 || JobBoardRefresh.consumeIfDirty()) {
        _reloadToken++;
      }
    });
  }

  void _onApplied() {
    setState(() {
      _applicationsRevision++;
      _workRevision++;
      _myJobsSegment = 0;
      _currentIndex = 2;
    });
  }

  Future<void> _openVaultTabOrPrompt() async {
    if (!SeekerShellAccess.isSignedInSeeker) {
      await SeekerLoginPromptSheet.show(
        context,
        message: '보관함은 개인회원 로그인 후 이용할 수 있습니다.',
      );
      return;
    }
    _switchTab(1);
  }

  @override
  void initState() {
    super.initState();
    final initial = normalizeSeekerTabIndex(widget.initialTabIndex);
    _currentIndex =
        SeekerShellAccess.isTabEnabled(initial) ? initial : SeekerShellAccess.mapTabIndex;
    _myJobsSegment = widget.initialMyJobsSegment.clamp(0, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSanctionNotices());
  }

  Future<void> _showSanctionNotices() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null || !mounted) return;
    await MemberSanctionGuard.showPendingNotices(context, email: email);
  }

  @override
  Widget build(BuildContext context) {
    return IndividualWebScaffold(
      currentIndex: _currentIndex,
      isItemEnabled: SeekerShellAccess.isTabEnabled,
      onSectionChanged: (index) {
        if (index == 2) _myJobsSegment = 0;
        _switchTab(index);
      },
      body: IndexedStack(
        index: _currentIndex,
        children: [
          IndividualMapTab(
            key: ValueKey('map_$_reloadToken'),
            reloadToken: _reloadToken,
            onOpenVaultTab: _openVaultTabOrPrompt,
            onApplied: _onApplied,
          ),
          IndividualVaultTab(
            key: ValueKey('vault_$_reloadToken'),
            reloadToken: _reloadToken,
            onApplied: _onApplied,
          ),
          IndividualMyJobsTab(
            key: ValueKey('jobs_${_applicationsRevision}_$_workRevision'),
            isActive: _currentIndex == 2,
            isWorkSegmentActive: _currentIndex == 2 && _myJobsSegment == 1,
            initialSegment: _myJobsSegment,
          ),
          IndividualChatTab(isActive: _currentIndex == 3),
          const IndividualMoreTab(),
        ],
      ),
    );
  }
}
