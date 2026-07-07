import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/data/repositories/account_recovery_repository.dart';
import 'package:map/features/auth/domain/services/email_verification_service.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';
import 'package:map/features/auth/domain/validators/email_validator.dart';
import 'package:map/features/auth/domain/validators/password_confirm_validator.dart';
import 'package:map/features/auth/domain/validators/password_validator.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/presentation/widgets/account_recovery_member_tabs.dart';
import 'package:map/features/auth/presentation/widgets/account_recovery_method_selector.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';

enum _ResetStep { form, verify, newPassword, done }

/// 비밀번호 찾기·재설정
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.initialMemberType = MemberType.individual,
  });

  final MemberType initialMemberType;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _phoneVerification = PhoneVerificationService();
  final _emailVerification = EmailVerificationService();

  late MemberType _memberType = widget.initialMemberType;
  AccountResetMethod _method = AccountResetMethod.phone;
  _ResetStep _step = _ResetStep.form;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _sendingCode = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _phoneVerifiedToken;
  String? _emailVerifiedToken;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  bool get _isCorporate => _memberType == MemberType.corporate;

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
    if (_method == AccountResetMethod.email) {
      final emailResult = EmailValidator.validate(_emailController.text);
      if (!emailResult.isValid) {
        _snack(emailResult.message ?? '이메일을 확인해 주세요.');
        return;
      }
      setState(() => _sendingCode = true);
      try {
        final devCode =
            await _emailVerification.sendCode(_emailController.text);
        if (!mounted) return;
        setState(() => _step = _ResetStep.verify);
        _snack('이메일로 인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
      } on Object catch (error) {
        _snack(AuthErrorMessage.phoneSendFailure(error));
      } finally {
        if (mounted) setState(() => _sendingCode = false);
      }
      return;
    }

    final phoneResult = PhoneValidator.validate(_phoneController.text);
    if (!phoneResult.isValid) {
      _snack(phoneResult.message ?? '휴대폰 번호를 확인해 주세요.');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      final devCode = await _phoneVerification.sendCode(_phoneController.text);
      if (!mounted) return;
      setState(() => _step = _ResetStep.verify);
      _snack('인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
    } on Object catch (error) {
      _snack(AuthErrorMessage.phoneSendFailure(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack('인증번호 6자리를 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_method == AccountResetMethod.email) {
        final verify = await _emailVerification.verifyAsync(
          _emailController.text,
          code,
          purpose: EmailVerificationPurpose.resetPassword,
        );
        if (!verify.verified || verify.emailVerifiedToken == null) {
          _snack('인증번호를 다시 확인해 주세요.');
          return;
        }
        _emailVerifiedToken = verify.emailVerifiedToken;
      } else {
        final verify = await _phoneVerification.verifyAsync(
          _phoneController.text,
          code,
          purpose: PhoneVerificationPurpose.resetPassword,
        );
        if (!verify.verified || verify.phoneVerifiedToken == null) {
          _snack('인증번호를 다시 확인해 주세요.');
          return;
        }
        _phoneVerifiedToken = verify.phoneVerifiedToken;
      }
      if (!mounted) return;
      setState(() => _step = _ResetStep.newPassword);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack(_isCorporate ? '담당자명을 입력해 주세요.' : '이름을 입력해 주세요.');
      return;
    }

    final emailResult = EmailValidator.validate(_emailController.text);
    final passwordResult = PasswordValidator.validate(_passwordController.text);
    final confirmResult = PasswordConfirmValidator.validate(
      password: _passwordController.text,
      confirm: _passwordConfirmController.text,
    );
    if (!emailResult.isValid ||
        !passwordResult.isValid ||
        !confirmResult.isValid) {
      _snack('입력 내용을 확인해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await AccountRecoveryRepository.resetPassword(
        memberType: _memberType,
        method: _method,
        email: _emailController.text,
        newPassword: _passwordController.text,
        displayName: name,
        contactPersonName: name,
        phone: _phoneController.text,
        phoneVerifiedToken: _phoneVerifiedToken,
        emailVerifiedToken: _emailVerifiedToken,
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.done);
      _phoneVerification.clear();
      _emailVerification.clear();
    } on Object catch (error) {
      _snack(error.toString().replaceFirst('ArgumentError: ', '').replaceFirst('IljariApiException: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              const SizedBox(height: 16),
              if (_step != _ResetStep.done) ...[
                AccountRecoveryMemberTabs(
                  value: _memberType,
                  onChanged: (type) => setState(() {
                    _memberType = type;
                    _method = AccountResetMethod.phone;
                    _step = _ResetStep.form;
                    _codeController.clear();
                  }),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _step == _ResetStep.done
                    ? '새 비밀번호로 로그인해 주세요.'
                    : '본인 확인 후 새 비밀번호를 설정합니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              if (_step == _ResetStep.form) ...[
                AccountRecoveryMethodSelector(
                  memberType: _memberType,
                  resetMethod: _method,
                  onResetMethodChanged: (method) => setState(() {
                    _method = method;
                    _codeController.clear();
                  }),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: _isCorporate ? '담당자명' : '이름',
                  hint: _isCorporate ? '가입 시 등록한 담당자명' : '실명',
                  controller: _nameController,
                ),
                const SizedBox(height: 16),
                if (_method == AccountResetMethod.email)
                  AuthTextField(
                    label: '이메일',
                    hint: '가입 시 등록한 이메일',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  )
                else
                  AuthTextField(
                    label: '휴대폰 번호',
                    hint: '01012345678',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _sendingCode ? '발송 중...' : '인증번호 받기',
                  onPressed: _sendingCode ? () {} : _sendCode,
                ),
              ] else if (_step == _ResetStep.verify) ...[
                AuthTextField(
                  label: '인증번호',
                  hint: '6자리',
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _submitting ? '확인 중...' : '인증 확인',
                  onPressed: _submitting ? () {} : _verifyCode,
                ),
              ] else if (_step == _ResetStep.newPassword) ...[
                AuthTextField(
                  label: '이메일 (아이디)',
                  hint: '가입 시 사용한 이메일',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: '새 비밀번호',
                  hint: '8자 이상',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: '새 비밀번호 확인',
                  hint: '비밀번호 재입력',
                  controller: _passwordConfirmController,
                  obscureText: _obscurePasswordConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePasswordConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(
                      () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
                    ),
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
