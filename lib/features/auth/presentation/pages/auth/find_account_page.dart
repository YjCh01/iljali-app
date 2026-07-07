import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/data/repositories/account_recovery_repository.dart';
import 'package:map/features/auth/domain/services/email_verification_service.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/presentation/widgets/account_recovery_member_tabs.dart';
import 'package:map/features/auth/presentation/widgets/account_recovery_method_selector.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';

enum _FindStep { form, verify, result }

/// 아이디(이메일) 찾기 — 개인/기업 · 연락처·이메일·사업자번호
class FindAccountPage extends StatefulWidget {
  const FindAccountPage({
    super.key,
    this.initialMemberType = MemberType.individual,
  });

  final MemberType initialMemberType;

  @override
  State<FindAccountPage> createState() => _FindAccountPageState();
}

class _FindAccountPageState extends State<FindAccountPage> {
  final _phoneVerification = PhoneVerificationService();
  final _emailVerification = EmailVerificationService();

  late MemberType _memberType = widget.initialMemberType;
  AccountFindMethod _method = AccountFindMethod.phone;
  _FindStep _step = _FindStep.form;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _brnController = TextEditingController();
  final _codeController = TextEditingController();

  bool _sendingCode = false;
  bool _submitting = false;
  String? _phoneVerifiedToken;
  String? _emailVerifiedToken;
  List<String> _maskedEmails = const [];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _brnController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isCorporate => _memberType == MemberType.corporate;

  String get _methodHint {
    if (_isCorporate) {
      return _method == AccountFindMethod.email
          ? '등록된 이메일로 인증 후 아이디를 확인합니다.'
          : '사업자등록번호와 담당자명으로 아이디를 찾을 수 있습니다.';
    }
    return _method == AccountFindMethod.email
        ? '등록된 이메일로 인증번호를 받아 아이디를 확인합니다.'
        : '이름과 휴대폰 번호로 인증 후 아이디를 확인합니다.';
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

  void _onMemberTypeChanged(MemberType type) {
    setState(() {
      _memberType = type;
      _method = AccountFindMethod.phone;
      _step = _FindStep.form;
      _codeController.clear();
      _phoneVerifiedToken = null;
      _emailVerifiedToken = null;
    });
  }

  void _onMethodChanged(AccountFindMethod method) {
    setState(() {
      _method = method;
      _step = _FindStep.form;
      _codeController.clear();
      _phoneVerifiedToken = null;
      _emailVerifiedToken = null;
    });
  }

  Future<void> _sendVerification() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack(_isCorporate ? '담당자명을 입력해 주세요.' : '이름을 입력해 주세요.');
      return;
    }

    if (_isCorporate && _method == AccountFindMethod.phone) {
      final brn = _brnController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (brn.length != 10) {
        _snack('사업자등록번호 10자리를 입력해 주세요.');
        return;
      }
      setState(() => _submitting = true);
      try {
        await _runFind();
      } on Object catch (error) {
        _snack(error.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '').replaceFirst('IljariApiException: ', ''));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    setState(() => _sendingCode = true);
    try {
      if (_method == AccountFindMethod.email) {
        final email = _emailController.text.trim();
        if (!email.contains('@')) {
          _snack('이메일을 확인해 주세요.');
          return;
        }
        final devCode = await _emailVerification.sendCode(email);
        if (!mounted) return;
        setState(() => _step = _FindStep.verify);
        _snack('이메일로 인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
      } else {
        final phoneResult = PhoneValidator.validate(_phoneController.text);
        if (!phoneResult.isValid) {
          _snack(phoneResult.message ?? '휴대폰 번호를 확인해 주세요.');
          return;
        }
        final devCode = await _phoneVerification.sendCode(_phoneController.text);
        if (!mounted) return;
        setState(() => _step = _FindStep.verify);
        _snack('인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
      }
    } on Object {
      _snack('인증번호 발송에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyAndFind() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack('인증번호 6자리를 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_method == AccountFindMethod.email) {
        final verify = await _emailVerification.verifyAsync(
          _emailController.text,
          code,
          purpose: EmailVerificationPurpose.findEmail,
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
          purpose: PhoneVerificationPurpose.findEmail,
        );
        if (!verify.verified || verify.phoneVerifiedToken == null) {
          _snack('인증번호를 다시 확인해 주세요.');
          return;
        }
        _phoneVerifiedToken = verify.phoneVerifiedToken;
      }
      await _runFind();
    } on Object catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '').replaceFirst('IljariApiException: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _runFind() async {
    final emails = await AccountRecoveryRepository.findEmails(
        memberType: _memberType,
        method: _isCorporate && _method == AccountFindMethod.phone
            ? AccountFindMethod.businessNumber
            : _method,
        displayName: _nameController.text.trim(),
        contactPersonName: _nameController.text.trim(),
        phone: _phoneController.text,
        phoneVerifiedToken: _phoneVerifiedToken,
        email: _emailController.text,
        emailVerifiedToken: _emailVerifiedToken,
        companyKey: _brnController.text,
      );
      if (!mounted) return;
      setState(() {
        _maskedEmails = emails;
        _step = _FindStep.result;
      });
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
                '아이디 찾기',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              AccountRecoveryMemberTabs(
                value: _memberType,
                onChanged: _onMemberTypeChanged,
              ),
              const SizedBox(height: 16),
              if (_step == _FindStep.result) ...[
                _buildResult(),
              ] else ...[
                AccountRecoveryMethodSelector(
                  memberType: _memberType,
                  findMethod: _method,
                  onFindMethodChanged: _onMethodChanged,
                ),
                const SizedBox(height: 12),
                Text(
                  _methodHint,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  label: _isCorporate ? '담당자명' : '이름',
                  hint: _isCorporate ? '가입 시 등록한 담당자명' : '실명',
                  controller: _nameController,
                ),
                const SizedBox(height: 16),
                if (_isCorporate && _method == AccountFindMethod.phone) ...[
                  AuthTextField(
                    label: '사업자등록번호',
                    hint: '10자리 숫자',
                    controller: _brnController,
                    keyboardType: TextInputType.number,
                  ),
                ] else if (_method == AccountFindMethod.email) ...[
                  AuthTextField(
                    label: '이메일',
                    hint: '가입 시 등록한 이메일',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ] else ...[
                  AuthTextField(
                    label: '휴대폰 번호',
                    hint: '01012345678',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                ],
                if (_step == _FindStep.verify) ...[
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: '인증번호',
                    hint: '6자리',
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _submitting
                      ? '확인 중...'
                      : _step == _FindStep.verify
                          ? '인증 후 아이디 찾기'
                          : _isCorporate && _method == AccountFindMethod.phone
                              ? '아이디 찾기'
                              : _sendingCode
                                  ? '발송 중...'
                                  : '인증번호 받기',
                  onPressed: _submitting || _sendingCode
                      ? () {}
                      : _step == _FindStep.verify
                          ? _verifyAndFind
                          : _sendVerification,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    return Column(
      children: [
        Icon(
          _maskedEmails.isEmpty
              ? Icons.info_outline_rounded
              : Icons.check_circle_outline_rounded,
          size: 48,
          color: _maskedEmails.isEmpty
              ? AppColors.textSecondary
              : AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _maskedEmails.isEmpty
              ? '입력하신 정보와 일치하는 계정을 찾지 못했습니다.'
              : '가입된 이메일 아이디',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (_maskedEmails.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._maskedEmails.map(
            (email) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: '로그인으로 돌아가기',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
