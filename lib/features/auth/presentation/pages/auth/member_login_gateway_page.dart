import 'package:flutter/material.dart';
import 'package:map/core/branding/iljari_ad_campaign.dart';
import 'package:map/core/branding/iljari_icon_painter.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/presentation/widgets/dev_test_login_panel.dart';
import 'package:map/features/auth/presentation/widgets/member_type_login_button.dart';

/// 로그인·가입 진입 — 지도에서 로그인/가입 탭 시 (맵 우선 UX)
class MemberLoginGatewayPage extends StatelessWidget {
  const MemberLoginGatewayPage({super.key});

  void _goToLogin(BuildContext context, MemberType memberType) {
    Navigator.of(context).pushNamed(
      AppRoutes.login,
      arguments: memberType,
    );
  }

  void _goToSignUp(BuildContext context, MemberType memberType) {
    Navigator.of(context).pushNamed(
      AppRoutes.signUp,
      arguments: memberType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.authBackground,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: canPop ? 8 : 40),
              Center(
                child: IljariAppIcon(
                  size: 100,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '일자리',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const IljariAdCampaignCopy(),
              const SizedBox(height: 32),
              MemberAuthSection(
                memberType: MemberType.corporate,
                onLogin: () => _goToLogin(context, MemberType.corporate),
                onSignUp: () => _goToSignUp(context, MemberType.corporate),
              ),
              const SizedBox(height: 16),
              MemberAuthSection(
                memberType: MemberType.individual,
                onLogin: () => _goToLogin(context, MemberType.individual),
                onSignUp: () => _goToSignUp(context, MemberType.individual),
              ),
              const SizedBox(height: 20),
              const DevTestLoginPanel(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
