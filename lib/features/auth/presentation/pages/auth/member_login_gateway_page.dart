import 'package:flutter/material.dart';

import 'package:map/core/branding/iljari_icon_painter.dart';

import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_strings.dart';

import 'package:map/core/constants/app_routes.dart';

import 'package:map/core/session/member_type.dart';

import 'package:map/features/auth/presentation/widgets/member_type_login_button.dart';



/// 앱 최초 진입 — 기업회원 / 개인회원 로그인 선택

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

    return Scaffold(

      backgroundColor: AppColors.authBackground,

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              const Spacer(flex: 2),

              Center(

                child: IljariAppIcon(

                  size: 112,

                  borderRadius: BorderRadius.circular(26),

                ),

              ),

              const SizedBox(height: 24),

              const Text(

                '일자리',

                textAlign: TextAlign.center,

                style: TextStyle(

                  fontSize: 42,

                  fontWeight: FontWeight.w800,

                  color: Colors.white,

                  letterSpacing: -0.5,

                ),

              ),

              const SizedBox(height: 10),

              Text(
                AppStrings.platformTagline,

                textAlign: TextAlign.center,

                style: TextStyle(

                  fontSize: 15,

                  height: 1.4,

                  color: Colors.white.withValues(alpha: 0.78),

                ),

              ),

              const Spacer(flex: 3),

              MemberTypeLoginButton(

                memberType: MemberType.corporate,

                onTap: () => _goToLogin(context, MemberType.corporate),

              ),

              const SizedBox(height: 6),

              TextButton(

                onPressed: () => _goToSignUp(context, MemberType.corporate),

                child: Text(

                  '기업회원 회원가입',

                  style: TextStyle(

                    color: Colors.white.withValues(alpha: 0.85),

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

              const SizedBox(height: 10),

              MemberTypeLoginButton(

                memberType: MemberType.individual,

                onTap: () => _goToLogin(context, MemberType.individual),

              ),

              const SizedBox(height: 6),

              TextButton(

                onPressed: () => _goToSignUp(context, MemberType.individual),

                child: Text(

                  '개인회원 회원가입',

                  style: TextStyle(

                    color: Colors.white.withValues(alpha: 0.85),

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

              const SizedBox(height: 32),

            ],

          ),

        ),

      ),

    );

  }

}


