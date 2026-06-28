import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/auth/data/repositories/individual_auth_repository.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/validators/email_validator.dart';
import 'package:map/features/auth/domain/validators/password_confirm_validator.dart';
import 'package:map/features/auth/domain/validators/password_validator.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';

enum _ResetPasswordStep { phone, verify, newPassword, done }

/// 비밀번호 찾기·재설정 — 휴대폰 본인인증 + 이메일 일치 확인
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _phoneVerification = PhoneVerificationService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  _ResetPasswordStep _step = _ResetPasswordStep.phone;
  bool _sendingCode = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _phoneError;
  String? _codeError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _phoneVerifiedToken;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _snack(String message) {
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

  Future<void> _sendCode() async {
    final result = PhoneValidator.validate(_phoneController.text);
    setState(() => _phoneError = result.message);
    if (!result.isValid) {
      _snack(result.message ?? '휴대폰 번호를 확인해 주세요.');
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final devCode = await _phoneVerification.sendCode(_phoneController.text);
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _step = _ResetPasswordStep.verify;
      });
      _snack('인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
    } on Object {
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _snack('인증번호 발송에 실패했습니다.');
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = '인증번호 6자리를 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    final verify = await _phoneVerification.verifyAsync(
      _phoneController.text,
      code,
      purpose: PhoneVerificationPurpose.resetPassword,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!verify.verified || verify.phoneVerifiedToken == null) {
      setState(() => _codeError = '인증번호가 올바르지 않습니다.');
      _snack('인증번호를 다시 확인해 주세요.');
      return;
    }

    setState(() {
      _codeError = null;
      _phoneVerifiedToken = verify.phoneVerifiedToken;
      _step = _ResetPasswordStep.newPassword;
    });
  }

  Future<void> _resetPassword() async {
    final token = _phoneVerifiedToken;
    if (token == null) {
      _snack('휴대폰 인증이 만료되었습니다. 처음부터 다시 시도해 주세요.');
      return;
    }

    final emailResult = EmailValidator.validate(_emailController.text);
    final passwordResult = PasswordValidator.validate(_passwordController.text);
    final confirmResult = PasswordConfirmValidator.validate(
      password: _passwordController.text,
      confirm: _passwordConfirmController.text,
    );

    setState(() {
      _emailError = emailResult.message;
      _passwordError = passwordResult.message;
      _passwordConfirmError = confirmResult.message;
    });

    if (!emailResult.isValid ||
        !passwordResult.isValid ||
        !confirmResult.isValid) {
      _snack('입력 내용을 확인해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await IndividualAuthRepository.resetPassword(
        email: _emailController.text,
        phone: _phoneController.text,
        phoneVerifiedToken: token,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _step = _ResetPasswordStep.done;
      });
      _phoneVerification.clear();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(error.toString().replaceFirst('ArgumentError: ', '').replaceFirst('IljariApiException: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: AuthFormCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '비밀번호 재설정',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == _ResetPasswordStep.done
                    ? '새 비밀번호로 로그인해 주세요.'
                    : '가입 시 등록한 휴대폰·이메일로 본인 확인 후\n새 비밀번호를 설정합니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 24),
              if (_step == _ResetPasswordStep.phone) ...[
                AuthTextField(
                  label: '휴대폰 번호',
                  hint: '01012345678',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  errorText: _phoneError,
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _sendingCode ? '발송 중...' : '인증번호 받기',
                  onPressed: _sendingCode ? () {} : _sendCode,
                ),
              ] else if (_step == _ResetPasswordStep.verify) ...[
                AuthTextField(
                  label: '휴대폰 번호',
                  hint: '인증된 번호',
                  controller: _phoneController,
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: '인증번호',
                  hint: '6자리',
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  errorText: _codeError,
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _submitting ? '확인 중...' : '인증 확인',
                  onPressed: _submitting ? () {} : _verifyCode,
                ),
              ] else if (_step == _ResetPasswordStep.newPassword) ...[
                AuthTextField(
                  label: '이메일',
                  hint: '가입 시 사용한 이메일',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: '새 비밀번호',
                  hint: '8자 이상, 2종류 이상 조합',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
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
                const SizedBox(height: 16),
                AuthTextField(
                  label: '새 비밀번호 확인',
                  hint: '비밀번호를 다시 입력',
                  controller: _passwordConfirmController,
                  obscureText: _obscurePasswordConfirm,
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
                const SizedBox(height: 8),
                Text(
                  '비밀번호는 8자 이상이며, 숫자·영문·특수문자 중 2가지 이상을 포함해야 합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _submitting ? '변경 중...' : '비밀번호 변경',
                  onPressed: _submitting ? () {} : _resetPassword,
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  '비밀번호가 변경되었습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: '로그인하기',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
