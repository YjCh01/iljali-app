import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/hiring/permanent_commission_sync_service.dart';
import 'package:map/core/job_board/job_board_refresh.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_applicants_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_attendance_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_chat_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_home_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_job_posts_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_more_tab.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_bottom_nav.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_create_job_post_entry_sheet.dart';

/// 기업회원 메인 셸 — 하단 6탭 + 홈 대시보드
class CorporateHomeShellPage extends StatefulWidget {
  const CorporateHomeShellPage({super.key});

  @override
  State<CorporateHomeShellPage> createState() => _CorporateHomeShellPageState();
}

class _CorporateHomeShellPageState extends State<CorporateHomeShellPage> {
  int _currentIndex = 0;
  int _jobPostsRevision = 0;
  int _chatRevision = 0;
  int _hiringRevision = 0;
  String? _applicantsFocusJobPostId;
  String? _applicantsFocusJobTitle;
  String? _mapFocusPostId;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _rebuildTabs();
    _syncPermanentCommission();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _syncPermanentCommission() async {
    if (!ProductFeatureFlags.isPermanentHireEnabled) return;
    final profile = AuthSession.instance.currentUser?.corporateProfile ??
        await AuthSession.instance.ensureCorporateProfile();
    if (profile == null) return;
    await PermanentCommissionSyncService().pullForCompany(
      companyKey: profile.companyKey,
      companyName: profile.companyName,
    );
  }

  void _rebuildTabs() {
    _tabs = [
      CorporateHomeTab(
        key: const ValueKey('corp-home'),
        onCreateJobPost: _openCreateJobPost,
        onSetupProfile: _openProfileSetup,
        onOpenJobPosts: () => _switchTab(1),
        onOpenChat: () => _switchTab(4),
        focusPostId: _mapFocusPostId,
        onFocusConsumed: _clearMapFocus,
      ),
      CorporateJobPostsTab(
        key: ValueKey(_jobPostsRevision),
        onViewApplicants: _openApplicantsForJob,
        onViewPostOnMap: _viewPostOnMap,
      ),
      CorporateApplicantsTab(
        key: ValueKey(_hiringRevision),
        focusJobPostId: _applicantsFocusJobPostId,
        focusJobTitle: _applicantsFocusJobTitle,
        onClearJobFilter: _clearApplicantsJobFilter,
      ),
      CorporateAttendanceTab(
        key: const ValueKey('corporate_attendance'),
        isActive: _currentIndex == 3,
      ),
      CorporateChatTab(
        key: ValueKey(_chatRevision),
        isActive: _currentIndex == 4,
      ),
      CorporateMoreTab(key: const ValueKey('corp-more')),
    ];
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 2) _hiringRevision++;
      if (index == 4) _chatRevision++;
      _rebuildTabs();
    });
  }

  void _openApplicantsForJob(CorporateJobPost post) {
    setState(() {
      _applicantsFocusJobPostId = post.id;
      _applicantsFocusJobTitle = post.title;
      _currentIndex = 2;
      _hiringRevision++;
      _rebuildTabs();
    });
  }

  void _clearApplicantsJobFilter() {
    if (_applicantsFocusJobPostId == null) return;
    setState(() {
      _applicantsFocusJobPostId = null;
      _applicantsFocusJobTitle = null;
      _hiringRevision++;
      _rebuildTabs();
    });
  }

  void _viewPostOnMap(CorporateJobPost post) {
    setState(() {
      _mapFocusPostId = post.id;
      _currentIndex = 0;
      _rebuildTabs();
    });
  }

  void _clearMapFocus() {
    if (_mapFocusPostId == null) return;
    setState(() => _mapFocusPostId = null);
  }

  Future<void> _openProfileSetup() async {
    final done = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateProfileSetup,
    );
    if (done == true && mounted) {
      setState(() => _rebuildTabs());
    }
  }

  Future<void> _openCreateJobPost() async {
    final entry = await showCorporateCreateJobPostEntrySheet(context);
    if (!mounted || entry == null) return;

    if (entry == CorporateCreateJobPostEntry.import) {
      final created = await Navigator.of(context).pushNamed<bool>(
        AppRoutes.corporateJobPostImport,
      );
      if (created == true && mounted) {
        JobBoardRefresh.markUpdated();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('공고가 등록되었습니다. 내 공고 탭에서 확인하세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        setState(() {
          _jobPostsRevision++;
          _chatRevision++;
          _rebuildTabs();
          _currentIndex = 1;
        });
      }
      return;
    }

    final flowResult =
        await Navigator.of(context).pushNamed<CorporateJobPostFlowResult>(
      AppRoutes.corporateCreateJobPost,
    );
    if (flowResult != null && mounted) {
      JobBoardRefresh.markUpdated();
      final tab = flowResult.shellTabIndex.clamp(0, _tabs.length - 1);
      if (tab == 1) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('공고가 등록되었습니다. 내 공고 탭에서 확인하세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      setState(() {
        _jobPostsRevision++;
        _chatRevision++;
        _rebuildTabs();
        _currentIndex = tab;
      });
    }
  }

  Future<void> _logout() async {
    await AuthSession.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.memberGateway,
      (_) => false,
    );
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
        title: Text(
          AuthSession.instance.currentUser?.corporateProfile?.companyName ??
              AuthSession.instance.currentUser?.name ??
              '기업',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: CorporateBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            if (index == 2 && _currentIndex != 2) {
              _applicantsFocusJobPostId = null;
              _applicantsFocusJobTitle = null;
            }
            _currentIndex = index;
            if (index == 2) _hiringRevision++;
            _rebuildTabs();
          });
        },
      ),
    );
  }
}
