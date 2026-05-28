import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:map/features/corporate/data/repositories/corporate_account_registry.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 기존 기업 로그인 사용자 — 기업·담당자 프로필 보완
class CorporateProfileSetupPage extends StatefulWidget {
  const CorporateProfileSetupPage({super.key});

  @override
  State<CorporateProfileSetupPage> createState() =>
      _CorporateProfileSetupPageState();
}

class _CorporateProfileSetupPageState extends State<CorporateProfileSetupPage> {
  final _companyController = TextEditingController();
  final _businessRegController = TextEditingController();
  final _departmentController = TextEditingController();
  final _contactPersonController = TextEditingController();

  String? _companyError;
  String? _businessRegError;
  String? _departmentError;
  String? _contactError;
  bool _submitting = false;
  CorporateMemberProfile? _assignedProfile;

  @override
  void dispose() {
    _companyController.dispose();
    _businessRegController.dispose();
    _departmentController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  Future<void> _assignCode() async {
    final company = _companyController.text.trim();
    final businessReg =
        _businessRegController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final department = _departmentController.text.trim();
    final contact = _contactPersonController.text.trim();

    setState(() {
      _companyError = company.isEmpty ? '회사명을 입력해 주세요.' : null;
      _businessRegError =
          businessReg.length != 10 ? '사업자등록번호 10자리를 입력해 주세요.' : null;
      _departmentError = department.isEmpty ? '담당부서를 입력해 주세요.' : null;
      _contactError = contact.isEmpty ? '담당자명을 입력해 주세요.' : null;
    });

    if (_companyError != null ||
        _businessRegError != null ||
        _departmentError != null ||
        _contactError != null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final registry = await CorporateAccountRegistry.create();
      final profile = await registry.registerHandler(
        companyName: company,
        businessRegistrationNumber: businessReg,
        department: department,
        contactPersonName: contact,
      );
      if (!mounted) return;
      setState(() {
        _assignedProfile = profile;
        _submitting = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('담당자 코드 발급에 실패했습니다.')),
      );
    }
  }

  Future<void> _save() async {
    final profile = _assignedProfile;
    final user = AuthSession.instance.currentUser;
    if (profile == null || user == null) return;

    await AuthSession.instance.signIn(
      user.copyWith(corporateProfile: profile),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _assignedProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('기업 정보 등록'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            profile == null
                ? '담당부서 및 담당자를\n입력해 주세요'
                : '담당자 코드가 발급되었습니다',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile == null
                ? '공고 등록·결제 보고서에 필요한 정보입니다.'
                : '아래 코드로 내부 결재 보고서가 생성됩니다.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 24),
          if (profile == null) ...[
            AuthTextField(
              label: '회사명',
              hint: '(주)일자리',
              controller: _companyController,
              errorText: _companyError,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: '사업자등록번호',
              hint: '1234567890',
              controller: _businessRegController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              errorText: _businessRegError,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: '담당부서',
              hint: '인사팀 / 채용팀',
              controller: _departmentController,
              errorText: _departmentError,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: '담당자명',
              hint: '홍길동',
              controller: _contactPersonController,
              errorText: _contactError,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: _submitting ? '코드 발급 중...' : '담당자 코드 발급',
              onPressed: _submitting ? () {} : _assignCode,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    profile.handlerCode,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${profile.companyName} · ${profile.department} · ${profile.contactPersonName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: '저장하고 계속하기',
              onPressed: _save,
            ),
          ],
        ],
      ),
    );
  }
}
