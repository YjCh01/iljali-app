import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/member_type.dart';

enum MemberAuthAction { login, signUp }

/// 게이트웨이 — 로그인(채움) / 회원가입(외곽) 동일 카드 레이아웃
class MemberTypeAuthButton extends StatelessWidget {
  const MemberTypeAuthButton({
    super.key,
    required this.memberType,
    required this.action,
    required this.onTap,
  });

  final MemberType memberType;
  final MemberAuthAction action;
  final VoidCallback onTap;

  bool get _isLogin => action == MemberAuthAction.login;
  bool get _isCorporate => memberType == MemberType.corporate;

  String get _title =>
      _isLogin ? memberType.loginLabel : memberType.signUpLabel;

  String get _subtitle => switch ((memberType, action)) {
        (MemberType.corporate, MemberAuthAction.login) =>
          '일용직·상시직 채용 · 인력 관리',
        (MemberType.individual, MemberAuthAction.login) =>
          '지도에서 일자리 찾기 · 지원',
        (MemberType.corporate, MemberAuthAction.signUp) =>
          '사업자 정보로 공고 등록 시작',
        (MemberType.individual, MemberAuthAction.signUp) =>
          '휴대폰 인증 · 지역·스케줄 설정',
      };

  IconData get _icon => switch ((memberType, action)) {
        (MemberType.corporate, MemberAuthAction.login) =>
          Icons.business_center_outlined,
        (MemberType.individual, MemberAuthAction.login) => Icons.person_outline,
        (MemberType.corporate, MemberAuthAction.signUp) =>
          Icons.domain_add_outlined,
        (MemberType.individual, MemberAuthAction.signUp) =>
          Icons.person_add_outlined,
      };

  @override
  Widget build(BuildContext context) {
    if (_isLogin) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.35),
              ),
            ),
            child: _row(
              iconBg: _isCorporate
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.primaryLight.withValues(alpha: 0.22),
              iconColor: AppColors.primary,
              titleColor: AppColors.textPrimary,
              subtitleColor: AppColors.textSecondary.withValues(alpha: 0.95),
              chevronColor: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          ),
          child: _row(
            iconBg: Colors.white.withValues(alpha: 0.14),
            iconColor: Colors.white,
            titleColor: Colors.white,
            subtitleColor: Colors.white.withValues(alpha: 0.78),
            chevronColor: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }

  Widget _row({
    required Color iconBg,
    required Color iconColor,
    required Color titleColor,
    required Color subtitleColor,
    required Color chevronColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: chevronColor),
        ],
      ),
    );
  }
}

/// 회원 유형별 로그인 + 회원가입 묶음
class MemberAuthSection extends StatelessWidget {
  const MemberAuthSection({
    super.key,
    required this.memberType,
    required this.onLogin,
    required this.onSignUp,
  });

  final MemberType memberType;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemberTypeAuthButton(
          memberType: memberType,
          action: MemberAuthAction.login,
          onTap: onLogin,
        ),
        const SizedBox(height: 8),
        MemberTypeAuthButton(
          memberType: memberType,
          action: MemberAuthAction.signUp,
          onTap: onSignUp,
        ),
      ],
    );
  }
}
