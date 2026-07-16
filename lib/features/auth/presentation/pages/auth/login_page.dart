import 'package:flutter/material.dart';
import 'package:map/core/dev/dev_auth_service.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/data/repositories/corporate_auth_repository.dart';
import 'package:map/features/auth/data/repositories/individual_auth_repository.dart';
import 'package:map/features/auth/domain/usecases/validate_login_form_usecase.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';
import 'package:map/features/auth/presentation/widgets/auth_error_dialog.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:map/features/auth/presentation/widgets/login_qc_quick_panel.dart';
import 'package:map/features/auth/presentation/widgets/social_login_buttons.dart';

/// 로그인 화면
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.memberType,
  });

  final MemberType memberType;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _validateLogin = const ValidateLoginFormUseCase();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;
  bool _submitting = false;

  bool get _isIndividual => widget.memberType == MemberType.individual;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showValidationSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.authBackground,
        ),
      );
  }

  Future<void> _signIn() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final result = _validateLogin(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() {
      _emailError = result.emailError;
      _passwordError = result.passwordError;
    });

    if (!result.isValid) {
      final message = result.firstError;
      if (message != null) _showValidationSnackBar(message);
      return;
    }

    setState(() => _submitting = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isIndividual) {
        await IndividualAuthRepository.signIn(email: email, password: password);
      } else {
        final devAccount = DevTestAccounts.matchCredentials(
          email: email,
          password: password,
        );
        if (DevAuthService.isEnabled && devAccount != null) {
          if (devAccount.memberType != widget.memberType) {
            throw ArgumentError('해당 계정은 개인회원 로그인에서 이용하세요.');
          }
          await DevAuthService.signIn(devAccount);
        } else {
          await CorporateAuthRepository.signIn(email: email, password: password);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showAuthErrorDialog(
        context,
        message: AuthErrorMessage.fromObject(error),
      );
    }
  }

  void _goToSignUp() {
    Navigator.of(context).pushNamed(
      AppRoutes.signUp,
      arguments: widget.memberType,
    );
  }

  void _goToFindAccount() {
    Navigator.of(context).pushNamed(
      AppRoutes.findAccount,
      arguments: widget.memberType,
    );
  }

  void _goToResetPassword() {
    Navigator.of(context).pushNamed(
      AppRoutes.resetPassword,
      arguments: widget.memberType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: AutofillGroup(
        child: AuthFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.memberType.loginLabel,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
              AuthTextField(
                label: '이메일',
                hint: 'example@email.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                errorText: _emailError,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '비밀번호',
                hint: '비밀번호를 입력하세요',
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              if (_isIndividual) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _goToFindAccount,
                      child: const Text(
                        '아이디 찾기',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '|',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                    TextButton(
                      onPressed: _goToResetPassword,
                      child: const Text(
                        '비밀번호 찾기',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _goToFindAccount,
                      child: const Text(
                        '아이디 찾기',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '|',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                    TextButton(
                      onPressed: _goToResetPassword,
                      child: const Text(
                        '비밀번호 찾기',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              AuthPrimaryButton(
                label: _submitting ? '로그인 중...' : '로그인',
                onPressed: _submitting ? () {} : _signIn,
              ),
              const SizedBox(height: 28),
              SocialLoginButtons(memberType: widget.memberType),
            ],
          ),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoginQcQuickPanel(memberType: widget.memberType),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _goToSignUp,
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.white70),
                children: [
                  TextSpan(text: '계정이 없으신가요? '),
                  TextSpan(
                    text: '회원가입하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
