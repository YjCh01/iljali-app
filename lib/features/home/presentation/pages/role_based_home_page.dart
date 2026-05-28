import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/presentation/pages/corporate_home_shell_page.dart';
import 'package:map/features/job_seeker/presentation/pages/individual_home_shell_page.dart';

/// 로그인 후 회원 유형별 홈 분기
class RoleBasedHomePage extends StatefulWidget {
  const RoleBasedHomePage({super.key});

  @override
  State<RoleBasedHomePage> createState() => _RoleBasedHomePageState();
}

class _RoleBasedHomePageState extends State<RoleBasedHomePage> {
  @override
  void initState() {
    super.initState();
    final user = AuthSession.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppRoutes.memberGateway);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user.isCorporate) {
      return const CorporateHomeShellPage();
    }

    return const IndividualHomeShellPage();
  }
}
