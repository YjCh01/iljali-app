import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_applications_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_chat_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_jobs_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_map_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_more_tab.dart';

import 'package:map/features/job_seeker/presentation/pages/tabs/individual_work_tab.dart';

import 'package:map/features/job_seeker/presentation/widgets/individual_bottom_nav.dart';

import 'package:map/core/widgets/app_back_button.dart';



/// 구직자 메인 셸 — 하단 6탭 (기본 화면)

class IndividualHomeShellPage extends StatefulWidget {

  const IndividualHomeShellPage({super.key});



  @override

  State<IndividualHomeShellPage> createState() =>

      _IndividualHomeShellPageState();

}



class _IndividualHomeShellPageState extends State<IndividualHomeShellPage> {

  int _currentIndex = 0;

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

            onOpenJobsTab: () => _switchTab(1),

            onApplied: _onApplied,

          ),

          IndividualJobsTab(

            key: ValueKey('jobs_$_reloadToken'),

            reloadToken: _reloadToken,

            onApplied: _onApplied,

            onOpenMapTab: () => _switchTab(0),

          ),

          IndividualApplicationsTab(key: ValueKey(_applicationsRevision)),

          IndividualWorkTab(
            key: ValueKey(_workRevision),
            isActive: _currentIndex == 3,
          ),

          const IndividualChatTab(),

          const IndividualMoreTab(),

        ],

      ),

      bottomNavigationBar: IndividualBottomNav(

        currentIndex: _currentIndex,

        onTap: _switchTab,

      ),

    );

  }

}


