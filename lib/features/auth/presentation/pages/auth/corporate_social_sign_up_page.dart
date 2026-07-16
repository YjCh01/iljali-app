import 'package:flutter/material.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/auth/data/repositories/corporate_auth_repository.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

class CorporateSocialSignUpArgs {
  const CorporateSocialSignUpArgs({
    required this.socialToken,
    required this.email,
    required this.displayName,
    required this.provider,
  });

  final String socialToken;
  final String email;
  final String displayName;
  final String provider;
}

/// 기업회원 소셜 1차 인증 후 — 휴대폰 문자 인증 + 회사 정보 + 가입 완료.
/// 사업자 인증(국세청 조회)은 가입 후 "내 정보"에서 별도로 진행한다.
class CorporateSocialSignUpPage extends StatefulWidget {
  const CorporateSocialSignUpPage({super.key, required this.args});

  final CorporateSocialSignUpArgs args;

  @override
  State<CorporateSocialSignUpPage> createState() =>
      _CorporateSocialSignUpPageState();
}

class _CorporateSocialSignUpPageState
    extends State<CorporateSocialSignUpPage> {
  final _phoneVerification = PhoneVerificationService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _businessRegController = TextEditingController();

  bool _sendingCode = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.args.displayName;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _companyNameController.dispose();
    _businessRegController.dispose();
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
    if (!result.isValid) {
      _snack(result.message ?? '휴대폰 번호를 확인해 주세요.');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await _phoneVerification.sendCode(_phoneController.text);
      if (!mounted) return;
      _snack('인증번호가 발송되었습니다.');
    } on Object catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _completeSignup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('이름을 입력해 주세요.');
      return;
    }
    final companyName = _companyNameController.text.trim();
    if (companyName.isEmpty) {
      _snack('회사명을 입력해 주세요.');
      return;
    }
    final businessReg = _businessRegController.text.trim();
    if (businessReg.isEmpty) {
      _snack('사업자등록번호를 입력해 주세요.');
      return;
    }
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack('인증번호 6자리를 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final verify = await _phoneVerification.verifyAsync(
        _phoneController.text,
        code,
        purpose: PhoneVerificationPurpose.signup,
      );
      if (!verify.verified || verify.phoneVerifiedToken == null) {
        _snack('인증번호를 다시 확인해 주세요.');
        return;
      }

      final profile = CorporateMemberProfile(
        companyName: companyName,
        businessRegistrationNumber: businessReg,
        department: '',
        contactPersonName: name,
        handlerCode: '',
        entityType: BusinessEntityType.corporation,
      );

      await CorporateAuthRepository.signUpSocial(
        socialToken: widget.args.socialToken,
        displayName: name,
        phone: _phoneController.text,
        phoneVerifiedToken: verify.phoneVerifiedToken!,
        profile: profile,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.corporateWelcomeOnboarding,
        (_) => false,
      );
    } on Object catch (error) {
      _snack(AuthErrorMessage.fromObject(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.args.provider.isNotEmpty
        ? widget.args.provider
        : '소셜';
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
              Text(
                '$provider 계정으로 기업회원 가입',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '본인 확인을 위해 휴대폰 문자 인증(6자리)을 완료하고, '
                '회사 정보를 입력해 주세요. 사업자 인증은 가입 후 진행할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '이메일',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.searchBarBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.searchBarBorder),
                ),
                child: Text(widget.args.email),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '담당자 이름',
                hint: '실명',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '회사명',
                hint: '(주)일자리',
                controller: _companyNameController,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '사업자등록번호',
                hint: "'-' 없이 10자리",
                controller: _businessRegController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '휴대폰 번호',
                hint: '01012345678',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AuthPrimaryButton(
                label: _sendingCode ? '발송 중...' : '인증번호 받기',
                onPressed: _sendingCode ? () {} : _sendCode,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: '인증번호',
                hint: '6자리',
                controller: _codeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: _submitting ? '가입 중...' : '가입 완료',
                onPressed: _submitting ? () {} : _completeSignup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
