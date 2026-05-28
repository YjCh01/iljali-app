import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/hiring/permanent_commission_sync_service.dart';
import 'package:map/core/job_board/job_board_refresh.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_applicants_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_attendance_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_chat_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_home_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_job_posts_tab.dart';
import 'package:map/features/corporate/presentation/pages/tabs/corporate_more_tab.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_bottom_nav.dart';

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
  int _homeRevision = 0;
  String? _applicantsFocusJobPostId;
  String? _applicantsFocusJobTitle;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.corporateProfileRevision
        .addListener(_onCorporateProfileChanged);
    _rebuildTabs();
    _syncPermanentCommission();
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision
        .removeListener(_onCorporateProfileChanged);
    super.dispose();
  }

  void _onCorporateProfileChanged() {
    if (!mounted) return;
    setState(() {
      _homeRevision++;
      _rebuildTabs();
    });
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
        key: ValueKey('corp-home-$_homeRevision'),
        onCreateJobPost: _openCreateJobPost,
        onSetupProfile: _openProfileSetup,
        onReviewApplicants: () => _switchTab(2),
        onOpenJobPosts: () => _switchTab(1),
        onOpenApplicants: () => _switchTab(2),
        onOpenAttendance: () => _switchTab(3),
        onOpenPackageShop: _openPackageShop,
        onOpenChat: () => _switchTab(4),
      ),
      CorporateJobPostsTab(
        key: ValueKey(_jobPostsRevision),
        onViewApplicants: _openApplicantsForJob,
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
      CorporateChatTab(key: ValueKey(_chatRevision)),
      const CorporateMoreTab(),
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

  Future<void> _openPackageShop() async {
    final purchased = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushPackageShop,
    );
    if (purchased == true && mounted) {
      setState(() {
        _homeRevision++;
        _rebuildTabs();
      });
    }
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
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateCreateJobPost,
    );
    if (created == true && mounted) {
      JobBoardRefresh.markUpdated();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('공고가 등록되었습니다. 구직자 지도·목록에 반영됩니다.'),
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
        title: const Text(
          '기업회원',
          style: TextStyle(fontWeight: FontWeight.w700),
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
