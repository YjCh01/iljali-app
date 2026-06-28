import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/location_consent_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/auth/domain/utils/resident_id_front.dart';
import 'package:map/features/auth/domain/validators/name_validator.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';
import 'package:map/features/job_seeker/domain/data/seeker_work_region_catalog.dart';
import 'package:map/features/job_seeker/domain/services/seeker_profile_sync_service.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_readiness.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_region_from_address.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_work_availability_picker.dart';

enum _ProfileOnboardingStep {
  memberInfo,
  homeAddress,
  region,
  schedule,
  photo,
  profile,
}

/// 개인회원 2단계 — 매칭·지원용 프로필 (이름·실주소·근무지역·스케줄 등)
class SeekerProfileOnboardingFlow extends StatefulWidget {
  const SeekerProfileOnboardingFlow({
    super.key,
    this.forJobApply = false,
  });

  /// true면 지원하기에서 진입 — 사진·소개 생략 가능, 완료 시 지원 흐름 재개
  final bool forJobApply;

  @override
  State<SeekerProfileOnboardingFlow> createState() =>
      _SeekerProfileOnboardingFlowState();
}

class _SeekerProfileOnboardingFlowState
    extends State<SeekerProfileOnboardingFlow> {
  _ProfileOnboardingStep _step = _ProfileOnboardingStep.memberInfo;

  final _nameController = TextEditingController();
  final _rrnFrontController = TextEditingController();
  final _experienceController = TextEditingController();
  final _regionSearchController = TextEditingController();

  bool _submitting = false;

  SeekerNationality? _nationality = SeekerNationality.domestic;
  final _selectedRegions = <String>{};
  SeekerWorkAvailability _availability = const SeekerWorkAvailability();
  String? _photoRef;
  WorkplaceAddress? _homeAddress;
  bool _signupLocationConsent = false;

  String? _nameError;
  String? _rrnFrontError;
  String? _regionError;
  String? _scheduleError;
  String? _homeAddressError;
  bool _addingRegionFromHomeAddress = false;
  String? _regionSidoFilter;

  static const _stepLabels = [
    '기본정보',
    '실주소',
    '근무지역',
    '스케줄',
    '사진',
    '프로필',
  ];

  @override
  void initState() {
    super.initState();
    _hydrateFromSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToFirstMissingStep();
    });
  }

  void _jumpToFirstMissingStep() {
    if (!widget.forJobApply) return;

    final user = AuthSession.instance.currentUser;
    final profile = user?.seekerProfile;
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (user?.name ?? '');

    if (!NameValidator.validate(name).isValid) {
      setState(() => _step = _ProfileOnboardingStep.memberInfo);
      return;
    }

    final rrnOk = ResidentIdFront.tryParse(_rrnFrontController.text) != null ||
        ResidentIdFront.tryParse(profile?.residentIdFront7 ?? '') != null;
    if (!rrnOk) {
      setState(() => _step = _ProfileOnboardingStep.memberInfo);
      return;
    }

    if (_homeAddress == null && profile?.hasHomeAddress != true) {
      setState(() => _step = _ProfileOnboardingStep.homeAddress);
      return;
    }

    if (_selectedRegions.isEmpty && (profile?.preferredRegions.isEmpty ?? true)) {
      setState(() => _step = _ProfileOnboardingStep.region);
      return;
    }

    if (_availability.isEmpty && (profile?.workAvailability.isEmpty ?? true)) {
      setState(() => _step = _ProfileOnboardingStep.schedule);
    }
  }

  void _hydrateFromSession() {
    final user = AuthSession.instance.currentUser;
    if (user == null) return;

    final name = user.name.trim();
    if (name.isNotEmpty) {
      _nameController.text = name;
    }

    final profile = user.seekerProfile;
    if (profile == null) return;

    if (profile.residentIdFront7 != null) {
      _rrnFrontController.text = profile.residentIdFront7!;
    }
    if (profile.nationality != null) {
      _nationality = profile.nationality;
    }
    _selectedRegions.addAll(profile.preferredRegions);
    _availability = profile.workAvailability;
    _photoRef = profile.profilePhotoRef;
    if (profile.experienceSummary != null) {
      _experienceController.text = profile.experienceSummary!;
    }
    if (profile.hasHomeAddress) {
      _homeAddress = WorkplaceAddress(
        roadAddress: profile.homeRoadAddress!,
        detailAddress: profile.homeDetailAddress,
        coordinate: profile.homeCoordinate,
      );
      if (profile.locationConsentAcceptedAt != null) {
        _signupLocationConsent = true;
      }
    }
  }

  bool get _hasSaveableInput {
    if (_nameController.text.trim().isNotEmpty) return true;
    if (_rrnFrontController.text.trim().isNotEmpty) return true;
    if (_homeAddress != null) return true;
    if (_selectedRegions.isNotEmpty) return true;
    if (!_availability.isEmpty) return true;
    if (_photoRef != null) return true;
    if (_experienceController.text.trim().isNotEmpty) return true;
    return false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rrnFrontController.dispose();
    _experienceController.dispose();
    _regionSearchController.dispose();
    super.dispose();
  }

  int get _stepIndex => _ProfileOnboardingStep.values.indexOf(_step);

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
    if (_step == _ProfileOnboardingStep.memberInfo) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step = _ProfileOnboardingStep.values[_stepIndex - 1];
    });
  }

  void _goNext(_ProfileOnboardingStep next) {
    setState(() => _step = next);
  }

  void _validateMemberInfo() {
    final nameResult = NameValidator.validate(_nameController.text);
    final rrnResult = ResidentIdFront.validate(_rrnFrontController.text);
    final parsedRrn = ResidentIdFront.tryParse(_rrnFrontController.text);

    setState(() {
      _nameError = nameResult.message;
      _rrnFrontError = rrnResult.message;
      if (parsedRrn != null) {
        _nationality = parsedRrn.nationality;
      }
    });

    if (!nameResult.isValid || !rrnResult.isValid) {
      _snack('입력 내용을 확인해 주세요.');
      return;
    }
    if (_nationality == null) {
      _snack('국적을 선택해 주세요.');
      return;
    }
    _goNext(_ProfileOnboardingStep.homeAddress);
  }

  Future<void> _pickHomeAddress() async {
    final result = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
      arguments: _homeAddress?.roadAddress,
    );
    if (result == null || !mounted) return;
    setState(() {
      _homeAddress = result;
      _homeAddressError = null;
    });
  }

  Future<void> _validateHomeAddress() async {
    if (_homeAddress == null || _homeAddress!.roadAddress.trim().isEmpty) {
      setState(() => _homeAddressError = '실주소를 등록해 주세요.');
      _snack('실주소를 검색·선택해 주세요.');
      return;
    }

    final granted = await LocationConsentService.ensureGranted(
      context,
      trigger: LocationConsentTrigger.signup,
      signupInAppConsent: _signupLocationConsent,
    );
    if (!granted || !mounted) return;

    setState(() {
      _homeAddressError = null;
      _signupLocationConsent = true;
    });
    _goNext(_ProfileOnboardingStep.region);
  }

  void _validateRegion() {
    _selectedRegions.removeWhere(
      (region) => !SeekerWorkRegionCatalog.isValidLabel(region),
    );
    if (_selectedRegions.isEmpty) {
      setState(() => _regionError = '희망 근무 지역을 하나 이상 선택해 주세요.');
      _snack('시·군·구 단위로 지역을 선택해 주세요.');
      return;
    }
    setState(() => _regionError = null);
    _goNext(_ProfileOnboardingStep.schedule);
  }

  Future<void> _addRegionFromHomeAddress() async {
    if (_addingRegionFromHomeAddress) return;

    final road = _homeAddress?.roadAddress.trim() ?? '';
    if (road.isEmpty) {
      _snack('먼저 이전 단계에서 실주소를 등록해 주세요.');
      return;
    }

    setState(() {
      _addingRegionFromHomeAddress = true;
      _regionError = null;
    });

    try {
      final region = SeekerRegionFromAddress.districtFromRoadAddress(road);
      if (region == null) {
        _snack('실주소에서 시·군·구를 찾지 못했습니다. 검색으로 선택해 주세요.');
        return;
      }

      if (!mounted) return;
      final alreadySelected = _selectedRegions.contains(region);
      setState(() => _selectedRegions.add(region));
      _snack(
        alreadySelected
            ? '$region은(는) 이미 선택되어 있습니다.'
            : '실주소 기준 $region 지역을 추가했습니다.',
      );
    } finally {
      if (mounted) setState(() => _addingRegionFromHomeAddress = false);
    }
  }

  void _validateSchedule() {
    if (_availability.isEmpty) {
      setState(() => _scheduleError = '근무 가능 시간을 선택해 주세요.');
      _snack('근무 가능 스케줄을 설정해 주세요.');
      return;
    }
    setState(() => _scheduleError = null);
    if (widget.forJobApply) {
      _completeForApply();
      return;
    }
    _goNext(_ProfileOnboardingStep.photo);
  }

  Future<void> _completeForApply() async {
    final nameResult = NameValidator.validate(_nameController.text);
    final rrnResult = ResidentIdFront.validate(_rrnFrontController.text);
    if (!nameResult.isValid || !rrnResult.isValid) {
      setState(() {
        _nameError = nameResult.message;
        _rrnFrontError = rrnResult.message;
        _step = _ProfileOnboardingStep.memberInfo;
      });
      _snack('이름·주민번호를 확인한 뒤 다시 시도해 주세요.');
      return;
    }
    if (_homeAddress == null || _homeAddress!.roadAddress.trim().isEmpty) {
      setState(() => _step = _ProfileOnboardingStep.homeAddress);
      _snack('실주소를 등록해 주세요.');
      return;
    }
    if (_selectedRegions.isEmpty) {
      setState(() => _step = _ProfileOnboardingStep.region);
      _snack('희망 근무 지역을 선택해 주세요.');
      return;
    }
    await _completeOnboarding();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _photoRef = file.path);
  }

  SeekerMemberProfile _buildDraftProfile(SeekerMemberProfile base) {
    final rrn = ResidentIdFront.tryParse(_rrnFrontController.text);
    final rrnText = _rrnFrontController.text.trim();
    final experience = _experienceController.text.trim();

    var profile = base.copyWith(
      phoneVerified: true,
      dateOfBirth: rrn?.birthDate ?? base.dateOfBirth,
      gender: rrn?.gender ?? base.gender,
      residentIdFront7: rrn?.display ??
          (rrnText.isEmpty ? base.residentIdFront7 : rrnText),
      nationality: _nationality ?? base.nationality,
      preferredRegions: _selectedRegions.isNotEmpty
          ? _selectedRegions.toList()
          : base.preferredRegions,
      workAvailability:
          _availability.isEmpty ? base.workAvailability : _availability,
      profilePhotoRef: _photoRef ?? base.profilePhotoRef,
      experienceSummary:
          experience.isEmpty ? base.experienceSummary : experience,
      homeRoadAddress: _homeAddress?.roadAddress ?? base.homeRoadAddress,
      homeDetailAddress: _homeAddress?.detailAddress ?? base.homeDetailAddress,
      homeLatitude: _homeAddress?.coordinate?.latitude ?? base.homeLatitude,
      homeLongitude: _homeAddress?.coordinate?.longitude ?? base.homeLongitude,
      onboardingCompletedAt: base.onboardingCompletedAt,
    );

    if (_signupLocationConsent && profile.hasHomeAddress) {
      profile = LocationConsentService.applySignupConsent(profile);
    }

    return profile;
  }

  Future<void> _saveProgress() async {
    if (_submitting) return;
    if (!_hasSaveableInput) {
      _snack('저장할 내용이 없습니다.');
      return;
    }

    final user = AuthSession.instance.currentUser;
    if (user == null) {
      _snack('로그인 후 프로필을 저장할 수 있습니다.');
      return;
    }

    setState(() => _submitting = true);

    final base =
        user.seekerProfile ?? const SeekerMemberProfile(phoneVerified: true);
    var profile = _buildDraftProfile(base);
    final name = _nameController.text.trim();
    if (SeekerProfileReadiness.isProfileFieldsReady(profile, displayName: name) &&
        profile.onboardingCompletedAt == null) {
      profile = profile.copyWith(onboardingCompletedAt: DateTime.now());
    }
    await SeekerProfileSyncService.persist(
      email: user.email,
      profile: profile,
      displayName: name.isNotEmpty ? name : user.name,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    final completed = profile.isOnboardingComplete;
    _snack(
      completed
          ? '프로필이 저장되었습니다. 이제 공고에 지원할 수 있습니다.'
          : '입력한 내용을 저장했습니다. 이어서 작성할 수 있습니다.',
    );
    Navigator.of(context).pop(completed);
  }

  void _cancelOnboarding() {
    if (_submitting) return;
    Navigator.of(context).pop();
  }

  Future<void> _completeOnboarding() async {
    if (_submitting) return;
    final user = AuthSession.instance.currentUser;
    if (user == null) {
      _snack('로그인 후 프로필을 완성할 수 있습니다.');
      return;
    }

    setState(() => _submitting = true);

    final rrn = ResidentIdFront.tryParse(_rrnFrontController.text);
    if (rrn == null) {
      setState(() => _submitting = false);
      _snack('주민번호 앞자리를 확인해 주세요.');
      return;
    }

    final base =
        user.seekerProfile ?? const SeekerMemberProfile(phoneVerified: true);
    final profile = LocationConsentService.applySignupConsent(
      base.copyWith(
        phoneVerified: true,
        dateOfBirth: rrn.birthDate,
        gender: rrn.gender,
        residentIdFront7: rrn.display,
        nationality: _nationality,
        preferredRegions: _selectedRegions.toList(),
        workAvailability: _availability,
        profilePhotoRef: _photoRef != null &&
                (_photoRef!.startsWith('http://') ||
                    _photoRef!.startsWith('https://'))
            ? _photoRef
            : null,
        experienceSummary: _experienceController.text.trim().isEmpty
            ? null
            : _experienceController.text.trim(),
        homeRoadAddress: _homeAddress?.roadAddress,
        homeDetailAddress: _homeAddress?.detailAddress,
        homeLatitude: _homeAddress?.coordinate?.latitude,
        homeLongitude: _homeAddress?.coordinate?.longitude,
        onboardingCompletedAt: DateTime.now(),
      ),
    );

    await SeekerProfileSyncService.persist(
      email: user.email,
      profile: profile,
      displayName: _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    _snack(
      widget.forJobApply
          ? '프로필이 저장되었습니다. 지원을 이어갑니다.'
          : '프로필이 저장되었습니다. 이제 공고에 지원할 수 있습니다.',
    );
    Navigator.of(context).pop(true);
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
              if (widget.forJobApply) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '지원하려면 아래 필수 정보를 입력해 주세요.\n'
                    '사진·경력 소개는 나중에 추가할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _StepProgress(
                current: _stepIndex,
                total: _ProfileOnboardingStep.values.length,
                label: _stepLabels[_stepIndex],
              ),
              const SizedBox(height: 20),
              switch (_step) {
                _ProfileOnboardingStep.memberInfo => _buildMemberInfoStep(),
                _ProfileOnboardingStep.homeAddress => _buildHomeAddressStep(),
                _ProfileOnboardingStep.region => _buildRegionStep(),
                _ProfileOnboardingStep.schedule => _buildScheduleStep(),
                _ProfileOnboardingStep.photo => _buildPhotoStep(),
                _ProfileOnboardingStep.profile => _buildProfileStep(),
              },
            ],
          ),
        ),
      ),
      bottom: widget.forJobApply
          ? TextButton(
              onPressed: _submitting ? null : _cancelOnboarding,
              child: Text(
                '취소',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : _ProfileOnboardingBottomActions(
              saving: _submitting,
              canSave: _hasSaveableInput && !_submitting,
              onSave: _saveProgress,
              onCancel: _cancelOnboarding,
            ),
    );
  }

  Widget _buildMemberInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '기본 정보',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '지원·매칭에 필요한 이름과 생년월일 정보를 입력합니다.',
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
          label: '주민번호 앞 7자리',
          hint: '000000-0',
          controller: _rrnFrontController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          errorText: _rrnFrontError,
          inputFormatters: const [ResidentIdFrontFormatter()],
          onSubmitted: (_) {
            final parsed = ResidentIdFront.tryParse(_rrnFrontController.text);
            if (parsed != null) {
              setState(() => _nationality = parsed.nationality);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          '형식: ㅁㅁㅁㅁㅁㅁ-ㅁ (생년월일 6자리 + 뒤 1자리, 0~9)',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
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
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateMemberInfo),
      ],
    );
  }

  Widget _buildHomeAddressStep() {
    final address = _homeAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '실주소 등록',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '등록한 주소를 중심으로 지도가 표시됩니다. 위치기반서비스 이용에 동의가 필요합니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _pickHomeAddress,
          icon: const Icon(Icons.search),
          label: Text(address == null ? '주소 검색' : '주소 다시 검색'),
        ),
        if (address != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.searchBarBorder),
            ),
            child: Text(
              address.roadAddress,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        if (_homeAddressError != null) ...[
          const SizedBox(height: 8),
          Text(_homeAddressError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateHomeAddress),
      ],
    );
  }

  Widget _buildRegionStep() {
    final query = _regionSearchController.text.trim();
    final districts = SeekerWorkRegionCatalog.search(
      query: query,
      sido: _regionSidoFilter,
      limit: 64,
    );

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
          '시·군·구 단위로 선택하세요. (예: 경기 의정부시, 서울 강남구)\n'
          '여러 곳 선택 가능합니다.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _homeAddress?.roadAddress.trim().isNotEmpty == true &&
                  !_addingRegionFromHomeAddress
              ? _addRegionFromHomeAddress
              : null,
          icon: _addingRegionFromHomeAddress
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.home_outlined),
          label: Text(
            _addingRegionFromHomeAddress
                ? '지역 추가 중…'
                : '실주소 지역 추가',
          ),
        ),
        if (_homeAddress != null &&
            _homeAddress!.roadAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '실주소: ${_homeAddress!.roadAddress}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
        if (_selectedRegions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '선택한 지역 (${_selectedRegions.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedRegions.map((region) {
              return InputChip(
                label: Text(region),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() => _selectedRegions.remove(region));
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _regionSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '시·군·구 검색 (예: 의정부, 강남, 수지구)',
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
        Text(
          '시·도',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: SeekerWorkRegionCatalog.sidos.map((sido) {
            final selected = _regionSidoFilter == sido;
            return FilterChip(
              label: Text(sido, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  _regionSidoFilter = value ? sido : null;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        if (_regionSidoFilter == null && query.isEmpty)
          Text(
            '시·도를 고르거나 검색창에 「의정부」「강남」처럼 입력하세요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        if (districts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '시·군·구',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: districts.map((region) {
                  final selected = _selectedRegions.contains(region);
                  return FilterChip(
                    label: Text(
                      region.contains(' ') ? region.split(' ').skip(1).join(' ') : region,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedRegions.add(region);
                        } else {
                          _selectedRegions.remove(region);
                        }
                        _regionError = null;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ] else if (_regionSidoFilter != null || query.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '검색 결과가 없습니다. 다른 키워드를 입력해 보세요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '다음', onPressed: _validateRegion),
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
          '요일을 고르고 24시간 시계(30분 단위)로 가능 시간을 추가하세요. 야간(익일 종료)도 설정할 수 있습니다.',
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
        AuthPrimaryButton(
          label: widget.forJobApply ? '완료하고 지원하기' : '다음',
          onPressed: _validateSchedule,
        ),
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
          onPressed: () => _goNext(_ProfileOnboardingStep.profile),
          child: const Text('건너뛰기'),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: '다음',
          onPressed: () => _goNext(_ProfileOnboardingStep.profile),
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
          label: _submitting ? '저장 중...' : '프로필 저장',
          onPressed: _submitting ? () {} : _completeOnboarding,
        ),
      ],
    );
  }
}

/// 프로필 작성 중단 — 부분 저장 · 취소 (공고 상세 액션 그리드와 동일한 2열 타일)
class _ProfileOnboardingBottomActions extends StatelessWidget {
  const _ProfileOnboardingBottomActions({
    required this.saving,
    required this.canSave,
    required this.onSave,
    required this.onCancel,
  });

  final bool saving;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OnboardingBottomTile(
            icon: Icons.save_outlined,
            label: saving ? '저장 중…' : '여기까지 저장하기',
            onTap: canSave ? onSave : null,
            accent: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OnboardingBottomTile(
            icon: Icons.close_rounded,
            label: '취소하기',
            onTap: saving ? null : onCancel,
          ),
        ),
      ],
    );
  }
}

class _OnboardingBottomTile extends StatelessWidget {
  const _OnboardingBottomTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = accent
        ? (enabled ? Colors.white : Colors.white.withValues(alpha: 0.35))
        : Colors.white.withValues(alpha: enabled ? 0.18 : 0.1);
    final fg = accent
        ? (enabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.45))
        : (enabled ? Colors.white : Colors.white54);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: fg),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
