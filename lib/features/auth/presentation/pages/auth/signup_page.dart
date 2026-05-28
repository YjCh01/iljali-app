import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/domain/usecases/validate_sign_up_form_usecase.dart';
import 'package:map/features/auth/presentation/pages/auth/corporate_sign_up_flow.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';

/// 회원가입 화면
class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.memberType,
  });

  final MemberType memberType;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.memberType == MemberType.corporate) {
      return const CorporateSignUpFlow();
    }
    return _IndividualSignUpForm(memberType: widget.memberType);
  }
}

class _IndividualSignUpForm extends StatefulWidget {
  const _IndividualSignUpForm({required this.memberType});

  final MemberType memberType;

  @override
  State<_IndividualSignUpForm> createState() => _IndividualSignUpFormState();
}

class _IndividualSignUpFormState extends State<_IndividualSignUpForm> {
  final _validateSignUp = const ValidateSignUpFormUseCase();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
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

  void _signUp() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = _validateSignUp(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirm: _passwordConfirmController.text,
    );

    setState(() {
      _nameError = result.nameError;
      _phoneError = result.phoneError;
      _emailError = result.emailError;
      _passwordError = result.passwordError;
      _passwordConfirmError = result.passwordConfirmError;
    });

    if (!result.isValid) {
      final message = result.firstError;
      if (message != null) _showValidationSnackBar(message);
      return;
    }

    await AuthSession.instance.signIn(
      AuthUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        memberType: widget.memberType,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
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
                widget.memberType.signUpLabel,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.memberType.signUpSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 28),
              AuthTextField(
                label: '이름',
                hint: '홍길동',
                controller: _nameController,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                errorText: _nameError,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '휴대폰 번호',
                hint: '01012345678',
                controller: _phoneController,
                keyboardType: TextInputType.number,
                maxLength: 11,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
                errorText: _phoneError,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              const SizedBox(height: 16),
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
                hint: '8자 이상 입력',
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 6),
              Text(
                '8자 이상 · 숫자/대·소문자/특수문자 중 1가지 이상 포함',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '비밀번호 확인',
                hint: '비밀번호를 다시 입력하세요',
                controller: _passwordConfirmController,
                obscureText: _obscurePasswordConfirm,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signUp(),
                errorText: _passwordConfirmError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePasswordConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(
                      () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: '가입하기',
                onPressed: _signUp,
              ),
            ],
          ),
        ),
      ),
      bottom: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 14, color: Colors.white70),
            children: [
              TextSpan(text: '이미 계정이 있으신가요? '),
              TextSpan(
                text: '로그인하기',
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
    );
  }
}
