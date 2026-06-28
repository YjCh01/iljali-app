import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/features/auth/data/repositories/individual_auth_repository.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/usecases/validate_basic_sign_up_form_usecase.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_readiness.dart';

enum _IndividualSignUpStep {
  phone,
  phoneVerify,
  account,
}

/// 개인회원 1단계 가입 — 휴대폰 본인인증 + 이메일(아이디)·비밀번호
///
/// 실주소·근무지역·스케줄 등 2단계는 [SeekerProfileOnboardingFlow].
class IndividualSignUpFlow extends StatefulWidget {
  const IndividualSignUpFlow({
    super.key,
    PhoneVerificationService? phoneVerification,
  }) : _phoneVerification = phoneVerification;

  final PhoneVerificationService? _phoneVerification;

  @override
  State<IndividualSignUpFlow> createState() => _IndividualSignUpFlowState();
}

class _IndividualSignUpFlowState extends State<IndividualSignUpFlow> {
  late final PhoneVerificationService _phoneVerification =
      widget._phoneVerification ?? PhoneVerificationService();
  final _validateBasic = const ValidateBasicSignUpFormUseCase();

  _IndividualSignUpStep _step = _IndividualSignUpStep.phone;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _phoneVerified = false;
  String? _phoneVerifiedToken;
  bool _sendingCode = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _termsAccepted = false;
  bool _submitting = false;

  String? _phoneError;
  String? _codeError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _termsError;

  static const _stepLabels = ['휴대폰', '본인인증', '계정 만들기'];

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  int get _stepIndex => _IndividualSignUpStep.values.indexOf(_step);

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

  void _goBack() {
    if (_step == _IndividualSignUpStep.phone) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step = _IndividualSignUpStep.values[_stepIndex - 1];
    });
  }

  void _goNext(_IndividualSignUpStep next) {
    setState(() => _step = next);
  }

  Future<void> _sendVerificationCode() async {
    final result = PhoneValidator.validate(_phoneController.text);
    setState(() => _phoneError = result.message);
    if (!result.isValid) {
      _snack(result.message ?? '휴대폰 번호를 확인해 주세요.');
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final code = await _phoneVerification.sendCode(_phoneController.text);
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _snack('인증번호가 발송되었습니다. (개발: $code)');
      _goNext(_IndividualSignUpStep.phoneVerify);
    } on Object {
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _snack('인증번호 발송에 실패했습니다.');
    }
  }

  Future<void> _verifyCode() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = '인증번호 6자리를 입력해 주세요.');
      return;
    }
    final result = await _phoneVerification.verifyAsync(
      phone,
      code,
      purpose: PhoneVerificationPurpose.signup,
    );
    if (!result.verified || result.phoneVerifiedToken == null) {
      setState(() => _codeError = '인증번호가 올바르지 않습니다.');
      _snack('인증번호를 다시 확인해 주세요.');
      return;
    }
    setState(() {
      _codeError = null;
      _phoneVerified = true;
      _phoneVerifiedToken = result.phoneVerifiedToken;
    });
    _goNext(_IndividualSignUpStep.account);
  }

  void _validateAccount() {
    final signUpResult = _validateBasic(
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirm: _passwordConfirmController.text,
    );

    String? termsError;
    if (!_termsAccepted) {
      termsError = '필수 약관에 동의해 주세요.';
    }

    setState(() {
      _emailError = signUpResult.emailError;
      _passwordError = signUpResult.passwordError;
      _passwordConfirmError = signUpResult.passwordConfirmError;
      _termsError = termsError;
    });

    if (!signUpResult.isValid || termsError != null) {
      _snack('입력 내용을 확인해 주세요.');
      return;
    }
    _completeBasicSignUp();
  }

  Future<void> _completeBasicSignUp() async {
    if (_submitting) return;
    final token = _phoneVerifiedToken;
    if (token == null || !_phoneVerified) {
      _snack('휴대폰 본인인증을 완료해 주세요.');
      return;
    }

    setState(() => _submitting = true);

    final email = _emailController.text.trim();
    final profile = SeekerMemberProfile(
      phoneVerified: true,
      termsAcceptedAt: DateTime.now(),
      termsVersionAccepted: LegalConsentCatalog.termsVersion,
      privacyVersionAccepted: LegalConsentCatalog.privacyVersion,
    );

    try {
      await IndividualAuthRepository.signUp(
        email: email,
        password: _passwordController.text,
        displayName: displayNameFromEmail(email),
        phone: _phoneController.text,
        phoneVerifiedToken: token,
        seekerProfile: profile,
      );
      _phoneVerification.clear();

      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(SeekerProfileReadiness.browseHintMessage);
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final raw = error.toString();
      final message = raw.contains('Failed to fetch') ||
              raw.contains('ClientException')
          ? '서버 연결에 실패했습니다. 네트워크를 확인하거나, 휴대폰 인증부터 다시 시도해 주세요.'
          : raw
              .replaceFirst('ArgumentError: ', '')
              .replaceFirst('StateError: ', '')
              .replaceFirst('IljariApiException: ', '');
      _snack(message.isEmpty ? '가입에 실패했습니다.' : message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: _goBack,
      ),
      body: AuthFormCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepProgress(
                current: _stepIndex,
                total: _IndividualSignUpStep.values.length,
                label: _stepLabels[_stepIndex],
              ),
              const SizedBox(height: 20),
              switch (_step) {
                _IndividualSignUpStep.phone => _buildPhoneStep(),
                _IndividualSignUpStep.phoneVerify => _buildPhoneVerifyStep(),
                _IndividualSignUpStep.account => _buildAccountStep(),
              },
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

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '휴대폰 본인인증',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '본인 확인을 위해 휴대폰 번호를 인증합니다.\n'
          '(추후 다날 등 본인인증 연동 예정)',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: '휴대폰 번호',
          hint: '01012345678',
          controller: _phoneController,
          keyboardType: TextInputType.number,
          maxLength: 11,
          errorText: _phoneError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: _sendingCode ? '발송 중...' : '인증번호 받기',
          onPressed: _sendingCode ? () {} : _sendVerificationCode,
        ),
      ],
    );
  }

  Widget _buildPhoneVerifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '인증번호 입력',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_phoneController.text.trim()} 으로 발송된 번호를 입력하세요.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: '인증번호',
          hint: '123456',
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          errorText: _codeError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _sendingCode ? null : _sendVerificationCode,
          child: Text(
            _sendingCode ? '재발송 중...' : '인증번호 다시 받기',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(label: '인증 확인', onPressed: _verifyCode),
      ],
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '계정 만들기',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '이메일이 로그인 아이디입니다. 가입 후 지도에서 공고를 바로 볼 수 있습니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: '이메일 (아이디)',
          hint: 'example@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '비밀번호',
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
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '숫자·영문·특수문자 중 2가지 이상을 포함해 주세요.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '비밀번호 확인',
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
            ),
            onPressed: () => setState(
              () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _termsAccepted,
            onChanged: (value) =>
                setState(() => _termsAccepted = value ?? false),
            title: const Text('서비스 이용약관 및 개인정보 처리방침에 동의합니다.'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_termsError != null)
                  Text(_termsError!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.legalDocuments),
                  child: const Text('약관·개인정보 전문 보기'),
                ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: _submitting ? '가입 중...' : '가입 완료 · 지도로 이동',
          onPressed: _submitting ? () {} : _validateAccount,
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.current,
    required this.total,
    required this.label,
  });

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final progress = (current + 1) / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            Text(
              '${current + 1}/$total',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.searchBarBorder,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
