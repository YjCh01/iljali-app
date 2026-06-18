import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/domain/services/mock_phone_verification_service.dart';
import 'package:map/features/auth/domain/usecases/validate_sign_up_form_usecase.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_work_availability_picker.dart';

enum _IndividualSignUpStep {
  phone,
  phoneVerify,
  memberInfo,
  region,
  jobCategories,
  schedule,
  photo,
  profile,
}

/// 개인회원 다단계 가입 — 휴대폰 인증 우선 → 매칭 정보 → 홈
class IndividualSignUpFlow extends StatefulWidget {
  const IndividualSignUpFlow({super.key});

  @override
  State<IndividualSignUpFlow> createState() => _IndividualSignUpFlowState();
}

class _IndividualSignUpFlowState extends State<IndividualSignUpFlow> {
  final _validateSignUp = const ValidateSignUpFormUseCase();
  final _phoneVerification = MockPhoneVerificationService.instance;

  _IndividualSignUpStep _step = _IndividualSignUpStep.phone;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _experienceController = TextEditingController();
  final _regionSearchController = TextEditingController();

  bool _phoneVerified = false;
  bool _sendingCode = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _termsAccepted = false;
  bool _submitting = false;

  SeekerGender? _gender;
  SeekerNationality? _nationality = SeekerNationality.domestic;
  final _selectedRegions = <String>{};
  final _selectedCategories = <String>{};
  SeekerWorkAvailability _availability = const SeekerWorkAvailability();
  String? _photoRef;

  String? _phoneError;
  String? _codeError;
  String? _nameError;
  String? _dobError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _termsError;
  String? _regionError;
  String? _categoryError;
  String? _scheduleError;

  static const _stepLabels = [
    '휴대폰',
    '인증',
    '회원정보',
    '근무지역',
    '희망업무',
    '스케줄',
    '사진',
    '프로필',
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _experienceController.dispose();
    _regionSearchController.dispose();
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

  void _verifyCode() {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = '인증번호 6자리를 입력해 주세요.');
      return;
    }
    if (!_phoneVerification.verify(phone, code)) {
      setState(() => _codeError = '인증번호가 올바르지 않습니다.');
      _snack('인증번호를 다시 확인해 주세요.');
      return;
    }
    setState(() {
      _codeError = null;
      _phoneVerified = true;
    });
    _goNext(_IndividualSignUpStep.memberInfo);
  }

  void _validateMemberInfo() {
    final signUpResult = _validateSignUp(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirm: _passwordConfirmController.text,
    );

    final dob = _dobController.text.trim();
    String? dobError;
    if (dob.isEmpty) {
      dobError = '생년월일을 입력해 주세요.';
    } else if (!RegExp(r'^\d{8}$').hasMatch(dob.replaceAll('-', ''))) {
      dobError = 'YYYYMMDD 형식으로 입력해 주세요.';
    }

    String? termsError;
    if (!_termsAccepted) {
      termsError = '필수 약관에 동의해 주세요.';
    }

    setState(() {
      _nameError = signUpResult.nameError;
      _phoneError = signUpResult.phoneError;
      _emailError = signUpResult.emailError;
      _passwordError = signUpResult.passwordError;
      _passwordConfirmError = signUpResult.passwordConfirmError;
      _dobError = dobError;
      _termsError = termsError;
    });

    if (!signUpResult.isValid || dobError != null || termsError != null) {
      _snack('입력 내용을 확인해 주세요.');
      return;
    }
    if (_gender == null || _nationality == null) {
      _snack('성별과 국적을 선택해 주세요.');
      return;
    }
    _goNext(_IndividualSignUpStep.region);
  }

  void _validateRegion() {
    if (_selectedRegions.isEmpty) {
      setState(() => _regionError = '희망 근무 지역을 하나 이상 선택해 주세요.');
      _snack('희망 근무 지역을 선택해 주세요.');
      return;
    }
    setState(() => _regionError = null);
    _goNext(_IndividualSignUpStep.jobCategories);
  }

  void _validateCategories() {
    if (_selectedCategories.isEmpty) {
      setState(() => _categoryError = '희망 업무를 하나 이상 선택해 주세요.');
      _snack('희망 업무를 선택해 주세요.');
      return;
    }
    setState(() => _categoryError = null);
    _goNext(_IndividualSignUpStep.schedule);
  }

  void _validateSchedule() {
    if (_availability.isEmpty) {
      setState(() => _scheduleError = '근무 가능 시간을 선택해 주세요.');
      _snack('근무 가능 스케줄을 설정해 주세요.');
      return;
    }
    setState(() => _scheduleError = null);
    _goNext(_IndividualSignUpStep.photo);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _photoRef = file.path);
  }

  Future<void> _completeSignUp() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final dobRaw = _dobController.text.replaceAll('-', '').trim();
    final year = int.parse(dobRaw.substring(0, 4));
    final month = int.parse(dobRaw.substring(4, 6));
    final day = int.parse(dobRaw.substring(6, 8));

    final profile = SeekerMemberProfile(
      phoneVerified: _phoneVerified,
      dateOfBirth: DateTime(year, month, day),
      gender: _gender,
      nationality: _nationality,
      preferredRegions: _selectedRegions.toList(),
      preferredJobCategories: _selectedCategories.toList(),
      workAvailability: _availability,
      profilePhotoRef: _photoRef,
      experienceSummary: _experienceController.text.trim().isEmpty
          ? null
          : _experienceController.text.trim(),
      termsAcceptedAt: DateTime.now(),
      onboardingCompletedAt: DateTime.now(),
    );

    await AuthSession.instance.signIn(
      AuthUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        memberType: MemberType.individual,
        seekerProfile: profile,
      ),
    );

    _phoneVerification.clear();

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
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
                _IndividualSignUpStep.memberInfo => _buildMemberInfoStep(),
                _IndividualSignUpStep.region => _buildRegionStep(),
                _IndividualSignUpStep.jobCategories => _buildJobCategoriesStep(),
                _IndividualSignUpStep.schedule => _buildScheduleStep(),
                _IndividualSignUpStep.photo => _buildPhotoStep(),
                _IndividualSignUpStep.profile => _buildProfileStep(),
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
          '휴대폰 번호 인증',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '본인 확인을 위해 휴대폰 번호를 먼저 인증합니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
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
          '${_phoneController.text}로 발송된 6자리 번호를 입력해 주세요.',
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

  Widget _buildMemberInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '회원정보',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '이름·생년월일·계정 정보와 약관 동의를 진행합니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: '이름',
          hint: '홍길동',
          controller: _nameController,
          errorText: _nameError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '생년월일',
          hint: '19900101',
          controller: _dobController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          errorText: _dobError,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        Text(
          '성별',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: SeekerGender.values.map((g) {
            return ChoiceChip(
              label: Text(g.label),
              selected: _gender == g,
              onSelected: (_) => setState(() => _gender = g),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          '국적',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: SeekerNationality.values.map((n) {
            return ChoiceChip(
              label: Text(n.label),
              selected: _nationality == n,
              onSelected: (_) => setState(() => _nationality = n),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '이메일',
          hint: 'example@email.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: '비밀번호',
          hint: '8자 이상 입력',
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
            subtitle: _termsError != null
                ? Text(_termsError!, style: const TextStyle(color: Colors.red))
                : null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateMemberInfo),
      ],
    );
  }

  Widget _buildRegionStep() {
    final query = _regionSearchController.text.trim();
    final filtered = query.isEmpty
        ? SeekerRegionPresets.all
        : SeekerRegionPresets.all
            .where((r) => r.contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '희망 근무 지역',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '근무하고 싶은 지역을 선택하세요. 여러 곳 선택 가능합니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _selectedRegions.add('현재 위치 (GPS)'));
          },
          icon: const Icon(Icons.my_location_outlined),
          label: const Text('현재 위치로 추가'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regionSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '지역 검색',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.searchBarBorder),
            ),
          ),
        ),
        if (_regionError != null) ...[
          const SizedBox(height: 8),
          Text(_regionError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map((region) {
            final selected = _selectedRegions.contains(region);
            return FilterChip(
              label: Text(region),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedRegions.add(region);
                  } else {
                    _selectedRegions.remove(region);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateRegion),
      ],
    );
  }

  Widget _buildJobCategoriesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '희망 업무',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '관심 있는 업무 유형을 선택하세요.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        if (_categoryError != null) ...[
          const SizedBox(height: 8),
          Text(_categoryError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SeekerJobCategories.all.map((category) {
            final selected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateCategories),
      ],
    );
  }

  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '근무 가능 스케줄',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '패턴을 빠르게 선택하거나, 요일별로 시간을 추가하세요.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        if (_scheduleError != null) ...[
          const SizedBox(height: 8),
          Text(_scheduleError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        SeekerWorkAvailabilityPicker(
          availability: _availability,
          onChanged: (value) => setState(() => _availability = value),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateSchedule),
      ],
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '프로필 사진',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '선택 사항입니다. 나중에 추가할 수 있어요.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.25),
            child: Icon(
              _photoRef != null ? Icons.check_circle_outline : Icons.person_outline,
              size: 48,
              color: _photoRef != null ? AppColors.primary : null,
            ),
          ),
        ),
        if (_photoRef != null) ...[
          const SizedBox(height: 8),
          Text(
            '사진이 선택되었습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('사진 선택'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _goNext(_IndividualSignUpStep.profile),
          child: const Text('건너뛰기'),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: '다음',
          onPressed: () => _goNext(_IndividualSignUpStep.profile),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '경력·소개',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '간단한 경력이나 자기소개를 적어 주세요. (선택)',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _experienceController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: '예: 물류센터 6개월, 포장·피킹 경험',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.searchBarBorder),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: _submitting ? '가입 중...' : '가입 완료',
          onPressed: _submitting ? () {} : _completeSignUp,
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
