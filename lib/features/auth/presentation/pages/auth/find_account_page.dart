import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/auth/data/repositories/individual_auth_repository.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';

enum _FindAccountStep { phone, verify, result }

/// 아이디(이메일) 찾기 — 휴대폰 본인인증 후 마스킹된 이메일 표시
class FindAccountPage extends StatefulWidget {
  const FindAccountPage({super.key});

  @override
  State<FindAccountPage> createState() => _FindAccountPageState();
}

class _FindAccountPageState extends State<FindAccountPage> {
  final _phoneVerification = PhoneVerificationService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  _FindAccountStep _step = _FindAccountStep.phone;
  bool _sendingCode = false;
  bool _submitting = false;
  String? _phoneError;
  String? _codeError;
  List<String> _maskedEmails = const [];

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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
        _step = _FindAccountStep.verify;
      });
      _snack('인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
    } on Object {
      if (!mounted) return;
      setState(() => _sendingCode = false);
      _snack('인증번호 발송에 실패했습니다.');
    }
  }

  Future<void> _verifyAndFind() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = '인증번호 6자리를 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    final verify = await _phoneVerification.verifyAsync(
      _phoneController.text,
      code,
      purpose: PhoneVerificationPurpose.findEmail,
    );
    if (!verify.verified || verify.phoneVerifiedToken == null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _codeError = '인증번호가 올바르지 않습니다.';
      });
      _snack('인증번호를 다시 확인해 주세요.');
      return;
    }

    try {
      final emails = await IndividualAuthRepository.findEmails(
        phone: _phoneController.text,
        phoneVerifiedToken: verify.phoneVerifiedToken!,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _maskedEmails = emails;
        _step = _FindAccountStep.result;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(error.toString().replaceFirst('Exception: ', ''));
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
            const SizedBox(height: 8),
            Text(
              '가입 시 등록한 휴대폰으로 본인인증 후\n이메일 아이디를 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 24),
            if (_step == _FindAccountStep.phone) ...[
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
            ] else if (_step == _FindAccountStep.verify) ...[
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
                label: _submitting ? '확인 중...' : '인증 후 아이디 찾기',
                onPressed: _submitting ? () {} : _verifyAndFind,
              ),
            ] else ...[
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
                    ? '해당 휴대폰으로 가입된 계정을 찾지 못했습니다.'
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
          ],
        ),
      ),
    );
  }
}
