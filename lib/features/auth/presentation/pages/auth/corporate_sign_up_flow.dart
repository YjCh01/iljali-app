import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/widgets/push_wallet_bonus_feedback.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/domain/entities/social_provider.dart';
import 'package:map/features/auth/domain/services/social_auth_service.dart';
import 'package:map/features/auth/data/repositories/corporate_auth_repository.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/domain/usecases/validate_sign_up_form_usecase.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/compliance/outsourcing_policy.dart';
import 'package:map/core/legal/legal_highlighted_text.dart';
import 'package:map/core/compliance/domain/business_verification_request.dart';
import 'package:map/core/compliance/services/business_verification_service.dart';
import 'package:map/core/compliance/services/mock_nts_business_api_service.dart';
import 'package:map/core/compliance/services/nts_service_factory.dart';
import 'package:map/core/compliance/verified_business_record.dart';
import 'package:map/features/auth/domain/usecases/corporate_sign_up_verification_gate.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/data/repositories/corporate_account_registry.dart';
import 'package:map/features/corporate/domain/entities/push_wallet_load_outcome.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

enum _CorporateSignUpStep {
  account,
  company,
  verification,
  handler,
  codeConfirm,
}

/// 기업회원 다단계 가입 — 계정 → 기업정보 → 담당부서/담당자 → 담당자 코드
class CorporateSignUpFlow extends StatefulWidget {
  const CorporateSignUpFlow({super.key});

  @override
  State<CorporateSignUpFlow> createState() => _CorporateSignUpFlowState();
}

class _CorporateSignUpFlowState extends State<CorporateSignUpFlow> {
  final _validateSignUp = const ValidateSignUpFormUseCase();
  final _phoneVerification = PhoneVerificationService();
  _CorporateSignUpStep _step = _CorporateSignUpStep.account;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _companyController = TextEditingController();
  final _businessRegController = TextEditingController();
  final _representativeController = TextEditingController();
  final _openingDateController = TextEditingController();
  final _departmentController = TextEditingController();
  final _contactPersonController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _submitting = false;
  bool _sendingPhoneCode = false;
  String? _phoneVerifiedToken;
  String? _phoneCodeError;

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _companyError;
  String? _businessRegError;
  String? _representativeError;
  String? _openingDateError;
  String? _departmentError;
  String? _contactError;
  String? _verificationError;

  BusinessEntityType _entityType = BusinessEntityType.corporation;
  String? _certificateImageRef;
  bool _policyAccepted = false;
  bool _verifying = false;
  VerifiedBusinessRecord? _verificationRecord;
  final _verificationGate = const CorporateSignUpVerificationGate();

  CorporateMemberProfile? _assignedProfile;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _companyController.dispose();
    _businessRegController.dispose();
    _representativeController.dispose();
    _openingDateController.dispose();
    _departmentController.dispose();
    _contactPersonController.dispose();
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

  void _onSocialSignUpTap(String provider) {
    final mapped = switch (provider.toLowerCase()) {
      'kakao' => SocialProvider.kakao,
      'naver' => SocialProvider.naver,
      'google' => SocialProvider.google,
      _ => null,
    };
    if (mapped == null) {
      _snack('$provider 로그인은 준비 중입니다.');
      return;
    }
    try {
      SocialAuthService().startLogin(
        provider: mapped,
        memberType: MemberType.corporate,
        action: 'signup',
      );
    } on Object {
      _snack(
        kIsWeb
            ? '$provider 로그인을 시작할 수 없습니다.'
            : '소셜 가입은 아직 웹에서만 이용할 수 있습니다. 이메일로 가입해 주세요.',
      );
    }
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _snack('휴대폰 번호를 확인해 주세요.');
      return;
    }
    setState(() {
      _sendingPhoneCode = true;
      _phoneCodeError = null;
      _phoneVerifiedToken = null;
    });
    try {
      final devCode = await _phoneVerification.sendCode(phone);
      if (!mounted) return;
      _snack('인증번호가 발송되었습니다.${devCode != '******' ? ' (개발: $devCode)' : ''}');
    } on Object {
      _snack('인증번호 발송에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _sendingPhoneCode = false);
    }
  }

  Future<bool> _ensurePhoneVerified() async {
    if (_phoneVerifiedToken != null) return true;
    final code = _phoneCodeController.text.trim();
    if (code.length != 6) {
      setState(() => _phoneCodeError = '인증번호 6자리를 입력해 주세요.');
      _snack('휴대폰 문자 인증을 완료해 주세요.');
      return false;
    }
    final result = await _phoneVerification.verifyAsync(
      _phoneController.text,
      code,
      purpose: PhoneVerificationPurpose.signup,
    );
    if (!result.verified || result.phoneVerifiedToken == null) {
      setState(() => _phoneCodeError = '인증번호가 올바르지 않습니다.');
      _snack('인증번호를 다시 확인해 주세요.');
      return false;
    }
    _phoneVerifiedToken = result.phoneVerifiedToken;
    return true;
  }

  Future<void> _continueFromAccount() async {
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
      if (message != null) _snack(message);
      return;
    }
    if (!await _ensurePhoneVerified()) return;
    setState(() => _step = _CorporateSignUpStep.company);
  }

  void _continueFromCompany() {
    final company = _companyController.text.trim();
    final request = BusinessVerificationRequest(
      businessRegistrationNumber: _businessRegController.text,
      representativeName: _representativeController.text,
      openingDate: _openingDateController.text,
      companyName: company,
    );
    setState(() {
      _companyError = company.isEmpty ? '회사명을 입력해 주세요.' : null;
      _businessRegError =
          request.normalizedBrn.length != 10 ? '사업자등록번호 10자리를 입력해 주세요.' : null;
      _representativeError =
          request.representativeName.trim().isEmpty ? '대표자명을 입력해 주세요.' : null;
      _openingDateError = request.normalizedOpeningDate.length != 8
          ? '개업일자를 YYYYMMDD 형식(8자리)으로 입력해 주세요.'
          : null;
    });
    final fieldError = request.validate();
    if (_companyError != null ||
        _businessRegError != null ||
        _representativeError != null ||
        _openingDateError != null ||
        fieldError != null) {
      _snack(fieldError ??
          _companyError ??
          _businessRegError ??
          _representativeError ??
          _openingDateError!);
      return;
    }
    setState(() {
      _verificationRecord = null;
      _step = _CorporateSignUpStep.verification;
    });
  }

  void _mockUploadCertificate() {
    _pickCertificateImage(fromCamera: false);
  }

  Future<void> _pickCertificateImage({required bool fromCamera}) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final url = await IljariApiClient().uploadBusinessCertMedia(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _certificateImageRef = url;
        _verificationError = null;
      });
      _snack('사업자등록증이 업로드되었습니다.');
    } on Object {
      setState(() {
        _certificateImageRef =
            'mock://certificate/${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
      _snack('업로드에 실패했습니다 — 오프라인 mock 참조로 대체합니다.');
    }
  }

  Future<void> _registerProvisionalSignup() async {
    if (!_policyAccepted) {
      setState(() => _verificationError = '이용 제한 약관에 동의해 주세요.');
      _snack('아웃소싱·인력공급 이용 제한 약관에 동의해 주세요.');
      return;
    }

    final request = BusinessVerificationRequest(
      businessRegistrationNumber: _businessRegController.text,
      representativeName: _representativeController.text,
      openingDate: _openingDateController.text,
      companyName: _companyController.text.trim(),
    );
    final fieldError = request.validate();
    if (fieldError != null) {
      setState(() => _verificationError = fieldError);
      _snack(fieldError);
      return;
    }

    setState(() {
      _verifying = true;
      _verificationError = null;
    });

    try {
      final service = BusinessVerificationService();
      final record = await service.registerProvisionalBusiness(
        request: request,
        entityType: _entityType,
        certificateImageRef: _certificateImageRef,
      );
      if (!mounted) return;
      setState(() {
        _verificationRecord = record;
        _verifying = false;
      });
      if (record.requiresAdminReview) {
        _snack('미인증 가입 완료. 사업자등록증 검토 후 유료 서비스를 이용할 수 있습니다.');
      } else {
        _snack('미인증 회원으로 등록되었습니다. 무료 공고를 이용해 보세요.');
      }
      setState(() => _step = _CorporateSignUpStep.handler);
    } on BusinessVerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verificationError = e.message;
      });
      _snack(e.message);
    } on Object {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verificationError = '미인증 가입 처리 중 오류가 발생했습니다.';
      });
      _snack('미인증 가입에 실패했습니다.');
    }
  }

  Future<void> _runBusinessVerification() async {
    if (!_policyAccepted) {
      setState(() => _verificationError = '이용 제한 약관에 동의해 주세요.');
      _snack('아웃소싱·인력공급 이용 제한 약관에 동의해 주세요.');
      return;
    }

    final request = BusinessVerificationRequest(
      businessRegistrationNumber: _businessRegController.text,
      representativeName: _representativeController.text,
      openingDate: _openingDateController.text,
      companyName: _companyController.text.trim(),
    );
    final fieldError = request.validate();
    if (fieldError != null) {
      setState(() => _verificationError = fieldError);
      _snack(fieldError);
      return;
    }

    setState(() {
      _verifying = true;
      _verificationError = null;
    });

    try {
      final service = BusinessVerificationService();
      final record = await service.verifyBusinessIdentity(
        request: request,
        entityType: _entityType,
        certificateImageRef: _certificateImageRef,
      );
      if (!mounted) return;
      setState(() {
        _verificationRecord = record;
        _verifying = false;
      });
      if (record.requiresAdminReview) {
        final reason = record.adminReviewReason ?? '';
        if (reason.contains('대표자명') || reason.contains('OCR')) {
          _snack('국세청 확인 완료. 등록증 대표자명은 관리자가 검토합니다.');
        } else {
          _snack('업종 검토 대상입니다. 관리자 승인 후 일부 기능이 제한될 수 있습니다.');
        }
      } else {
        _snack('국세청 사업자 확인이 완료되었습니다.');
      }
    } on BusinessVerificationException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verificationError = e.message;
      });
      _snack(e.message);
    } on Object {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verificationError = '검증 중 오류가 발생했습니다.';
      });
      _snack('사업자 검증에 실패했습니다.');
    }
  }

  void _continueFromVerification() {
    if (_verificationRecord != null) {
      setState(() => _step = _CorporateSignUpStep.handler);
      return;
    }
    _runBusinessVerification();
  }

  Future<void> _assignHandlerCode() async {
    if (!_verificationGate.canProceedToHandler(record: _verificationRecord)) {
      final message = _verificationGate.handlerBlockedMessage(
        record: _verificationRecord,
      );
      _snack(message ?? '사업자 확인이 필요합니다.');
      setState(() => _step = _CorporateSignUpStep.verification);
      return;
    }
    final department = _departmentController.text.trim();
    final contact = _contactPersonController.text.trim();
    setState(() {
      _departmentError = department.isEmpty ? '담당부서를 입력해 주세요.' : null;
      _contactError = contact.isEmpty ? '담당자명을 입력해 주세요.' : null;
    });
    if (_departmentError != null || _contactError != null) {
      _snack(_departmentError ?? _contactError!);
      return;
    }

    setState(() => _submitting = true);
    try {
      final registry = await CorporateAccountRegistry.create();
      final profile = await registry.registerHandler(
        companyName: _companyController.text.trim(),
        businessRegistrationNumber: _businessRegController.text,
        department: department,
        contactPersonName: contact,
      );
      final record = _verificationRecord;
      final enriched = record == null
          ? profile
          : profile.copyWith(
              entityType: record.entityType,
              verificationStatus: record.status,
              requiresAdminReview: record.requiresAdminReview,
              adminReviewReason: record.adminReviewReason,
              certificateImageRef: record.certificateImageRef,
              industryName: record.industryName,
              policyAcceptedAt: DateTime.now(),
              termsVersionAccepted: LegalConsentCatalog.termsVersion,
              privacyVersionAccepted: LegalConsentCatalog.privacyVersion,
              outsourcingPolicyVersionAccepted:
                  LegalConsentCatalog.outsourcingPolicyVersion,
            );
      if (!mounted) return;
      setState(() {
        _assignedProfile = enriched;
        _step = _CorporateSignUpStep.codeConfirm;
        _submitting = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('담당자 코드 발급에 실패했습니다.');
    }
  }

  Future<void> _completeSignUp() async {
    final profile = _assignedProfile;
    if (profile == null) return;

    if (!_verificationGate.canCompleteSignUp(
      record: _verificationRecord,
      hasAssignedProfile: true,
    )) {
      final message = _verificationGate.completeBlockedMessage(
        record: _verificationRecord,
        hasAssignedProfile: true,
      );
      _snack(message ?? '가입을 완료할 수 없습니다.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final token = _phoneVerifiedToken;
      if (token == null || token.isEmpty) {
        _snack('휴대폰 문자 인증이 필요합니다.');
        return;
      }
      await CorporateAuthRepository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        phoneVerifiedToken: token,
        profile: profile,
      );

      final signedIn = AuthSession.instance.currentUser?.corporateProfile;
      PushWalletLoadOutcome? walletOutcome;
      if (signedIn != null) {
        walletOutcome = await PushWalletService().loadWalletDetailed(signedIn);
      }

      if (!mounted) return;
      if (walletOutcome != null) {
        showPushWalletBonusSnackBar(context, walletOutcome);
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.corporateWelcomeOnboarding,
        (_) => false,
      );
    } on Object catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('ArgumentError: ', '')
          .replaceFirst('IljariApiException: ', '');
      _snack(message.isEmpty ? '가입에 실패했습니다.' : message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () {
          if (_step == _CorporateSignUpStep.account) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              _step = switch (_step) {
                _CorporateSignUpStep.company => _CorporateSignUpStep.account,
                _CorporateSignUpStep.verification =>
                  _CorporateSignUpStep.company,
                _CorporateSignUpStep.handler =>
                  _CorporateSignUpStep.verification,
                _CorporateSignUpStep.codeConfirm =>
                  _CorporateSignUpStep.handler,
                _ => _CorporateSignUpStep.account,
              };
            });
          }
        },
      ),
      body: AuthFormCard(
        child: switch (_step) {
          _CorporateSignUpStep.account => _buildAccountStep(),
          _CorporateSignUpStep.company => _buildCompanyStep(),
          _CorporateSignUpStep.verification => _buildVerificationStep(),
          _CorporateSignUpStep.handler => _buildHandlerStep(),
          _CorporateSignUpStep.codeConfirm => _buildCodeConfirmStep(),
        },
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

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '기업회원 가입',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '소셜 또는 아이디로 가입합니다. 모든 경로에서 휴대폰 문자 인증(6자리)이 필요합니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: '카카오',
                color: const Color(0xFFFEE500),
                textColor: Colors.black87,
                onTap: () => _onSocialSignUpTap('Kakao'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialButton(
                label: '네이버',
                color: const Color(0xFF03C75A),
                onTap: () => _onSocialSignUpTap('Naver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialButton(
                label: 'Google',
                color: Colors.white,
                textColor: AppColors.textPrimary,
                onTap: () => _onSocialSignUpTap('Google'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: Divider(
                    color: AppColors.textSecondary.withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '아이디 가입',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
            Expanded(
                child: Divider(
                    color: AppColors.textSecondary.withValues(alpha: 0.3))),
          ],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '이름',
          hint: '홍길동',
          controller: _nameController,
          keyboardType: TextInputType.name,
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
          textInputAction: TextInputAction.next,
          errorText: _phoneError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AuthTextField(
                label: '인증번호',
                hint: '6자리',
                controller: _phoneCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                errorText: _phoneCodeError,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: OutlinedButton(
                onPressed: _sendingPhoneCode ? null : _sendPhoneCode,
                child: Text(_sendingPhoneCode ? '발송 중' : '인증번호'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '이메일',
          hint: 'example@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '비밀번호',
          hint: '8자 이상 입력',
          controller: _passwordController,
          obscureText: _obscurePassword,
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
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '비밀번호 확인',
          hint: '비밀번호를 다시 입력하세요',
          controller: _passwordConfirmController,
          obscureText: _obscurePasswordConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueFromAccount(),
          errorText: _passwordConfirmError,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePasswordConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => setState(
              () => _obscurePasswordConfirm = !_obscurePasswordConfirm,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: '다음 — 기업 정보',
          onPressed: _continueFromAccount,
        ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '기업 정보',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '회사명·사업자등록번호·대표자명·개업연월일을 입력해 주세요. '
          '국세청(공공데이터) 진위확인에 사용됩니다.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: '회사명',
          hint: '(주)일자리',
          controller: _companyController,
          textInputAction: TextInputAction.next,
          errorText: _companyError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '사업자등록번호',
          hint: '1234567890',
          controller: _businessRegController,
          keyboardType: TextInputType.number,
          maxLength: 12,
          textInputAction: TextInputAction.next,
          errorText: _businessRegError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '대표자명',
          hint: '홍길동',
          controller: _representativeController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          errorText: _representativeError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '개업일자',
          hint: '20200115 (YYYYMMDD)',
          controller: _openingDateController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueFromCompany(),
          errorText: _openingDateError,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
        ),
        if (NtsServiceFactory.isMockMode) ...[
          const SizedBox(height: 12),
          Text(
            '개발 모드: ${MockNtsBusinessApiService.devBrn} · '
            '${MockNtsBusinessApiService.devOpeningDate} · '
            '${MockNtsBusinessApiService.devRepresentativeName}',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: '다음 — 사업자 검증',
          onPressed: _continueFromCompany,
        ),
      ],
    );
  }

  Widget _buildVerificationStep() {
    final record = _verificationRecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '사업자 검증',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '입력하신 정보로 국세청(공공데이터포털) 사업자등록번호 진위확인을 진행합니다. '
          '신규 사업장 등 국세청에 아직 반영되지 않은 경우 미인증 회원으로 가입할 수 있으며, '
          '무료 공고 등록 후 사업자등록증 제출·승인 시 유료 서비스를 이용할 수 있습니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '사업자 유형',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<BusinessEntityType>(
          segments: const [
            ButtonSegment(
              value: BusinessEntityType.soleProprietor,
              label: Text('개인사업자'),
            ),
            ButtonSegment(
              value: BusinessEntityType.corporation,
              label: Text('법인'),
            ),
          ],
          selected: {_entityType},
          onSelectionChanged: (selection) {
            setState(() => _entityType = selection.first);
          },
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _mockUploadCertificate,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(
            _certificateImageRef == null ? '사업자등록증 업로드 (선택)' : '업로드 완료 — 다시 선택',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickCertificateImage(fromCamera: true),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('카메라로 촬영'),
        ),
        if (_certificateImageRef != null) ...[
          const SizedBox(height: 8),
          Text(
            '파일: ${_certificateImageRef!.split('/').last}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                OutsourcingPolicy.termsTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                future: rootBundle.loadString(OutsourcingPolicy.termsAssetPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Text(
                      '약관을 불러오지 못했습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    );
                  }
                  return LegalHighlightedText(raw: snapshot.data!);
                },
              ),
            ],
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _policyAccepted,
          onChanged: (value) =>
              setState(() => _policyAccepted = value ?? false),
          title: const Text(
            '서비스 이용약관·개인정보처리방침 및 아웃소싱 이용 제한 약관에 동의합니다.',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.legalDocuments),
            child: const Text('이용약관·개인정보 전문 보기'),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (record != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: record.requiresAdminReview
                  ? Colors.orange.withValues(alpha: 0.12)
                  : AppColors.primaryLight.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              switch (record.status) {
                BusinessVerificationStatus.pending => record.requiresAdminReview
                    ? '미인증 · 사업자등록증 검토 대기'
                    : '미인증 가입 — 무료 공고 이용 가능',
                BusinessVerificationStatus.adminReviewRequired
                    when record.requiresAdminReview =>
                  record.industryName?.isNotEmpty == true
                      ? '업종「${record.industryName}」— 관리자 검토·Enterprise 가입 필요'
                      : '사업자등록증 검토 대기 — 승인 후 유료 서비스 이용',
                _ => '검증 완료 · ${record.industryName ?? ''}',
              },
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
        if (_verificationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _verificationError!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: _verifying
              ? '확인 중...'
              : record == null
                  ? '국세청 확인 후 다음'
                  : '다음 — 담당자 정보',
          onPressed: _verifying ? () {} : _continueFromVerification,
        ),
        if (record == null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '사업자 인증 없이 먼저 가입할 수 있어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '신규 사업장 등 국세청에 아직 반영되지 않았다면, 인증 없이 우선 가입해 '
                  '무료 공고를 이용하고 나중에 사업자등록증으로 인증할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _verifying ? null : _registerProvisionalSignup,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('미인증 회원으로 가입'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHandlerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '담당부서 및 담당자를\n입력해주세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.35,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '같은 기업의 담당자마다 6자리 코드가 자동 발급됩니다. (로그인용 아님)',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: '담당부서',
          hint: '인사팀 / 채용팀',
          controller: _departmentController,
          textInputAction: TextInputAction.next,
          errorText: _departmentError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '담당자명',
          hint: '홍길동',
          controller: _contactPersonController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _assignHandlerCode(),
          errorText: _contactError,
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: _submitting ? '코드 발급 중...' : '담당자 코드 발급',
          onPressed: () {
            if (!_submitting) _assignHandlerCode();
          },
        ),
      ],
    );
  }

  Widget _buildCodeConfirmStep() {
    final profile = _assignedProfile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '담당자 코드가 발급되었습니다',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Text(
                profile.handlerCode,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile.companyName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${profile.department} · ${profile.contactPersonName}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '공고 등록·결제 시 이 코드로 내부 결재 보고서가 생성됩니다.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: '가입 완료',
          onPressed: _completeSignUp,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
