import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_applications_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_chat_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_map_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_more_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_vault_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_work_tab.dart';

import 'package:map/features/job_seeker/presentation/widgets/individual_bottom_nav.dart';

import 'package:map/core/widgets/app_back_button.dart';

/// 구직자 메인 셸 — 지도에서 공고 탐색 · 보관함에 저장
class IndividualHomeShellPage extends StatefulWidget {
  const IndividualHomeShellPage({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<IndividualHomeShellPage> createState() =>
      _IndividualHomeShellPageState();
}

class _IndividualHomeShellPageState extends State<IndividualHomeShellPage> {
  late int _currentIndex;

  int _reloadToken = 0;

  int _applicationsRevision = 0;
  int _workRevision = 0;

  void _switchTab(int index) {
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
      _currentIndex = 2;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const AppRootLeading(),
        title: const Text(
          '구직자',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          IndividualMapTab(
            key: ValueKey('map_$_reloadToken'),
            reloadToken: _reloadToken,
            onOpenVaultTab: () => _switchTab(1),
            onApplied: _onApplied,
          ),
          IndividualVaultTab(
            key: ValueKey('vault_$_reloadToken'),
            reloadToken: _reloadToken,
            onApplied: _onApplied,
          ),
          IndividualApplicationsTab(key: ValueKey(_applicationsRevision)),
          IndividualWorkTab(
            key: ValueKey(_workRevision),
            isActive: _currentIndex == 3,
          ),
          const IndividualChatTab(),
          IndividualMoreTab(onOpenVaultTab: () => _switchTab(1)),
        ],
      ),
      bottomNavigationBar: IndividualBottomNav(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}
