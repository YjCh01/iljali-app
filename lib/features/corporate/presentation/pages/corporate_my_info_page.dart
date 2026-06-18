import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 기업회원 — 내정보 관리 (사업자 소재지·담당자·검증 상태)
class CorporateMyInfoPage extends StatefulWidget {
  const CorporateMyInfoPage({super.key});

  @override
  State<CorporateMyInfoPage> createState() => _CorporateMyInfoPageState();
}

class _CorporateMyInfoPageState extends State<CorporateMyInfoPage> {
  CorporateMemberProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    AuthSession.instance.corporateProfileRevision.addListener(_loadProfile);
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision.removeListener(_loadProfile);
    super.dispose();
  }

  void _loadProfile() {
    setState(() {
      _profile = AuthSession.instance.currentUser?.corporateProfile;
    });
  }

  bool get _hasHeadOffice {
    final addr = _profile?.businessHeadOfficeAddress?.trim();
    return addr != null && addr.isNotEmpty;
  }

  Future<void> _editHeadOffice() async {
    final result = await Navigator.of(context).pushNamed<WorkplaceAddress>(
      AppRoutes.corporateWorkplaceSearch,
      arguments: _profile?.businessHeadOfficeAddress,
    );
    if (result == null || !mounted) return;

    final current = _profile;
    if (current == null) return;

    final updated = current.copyWith(
      businessHeadOfficeAddress: result.roadAddress,
      businessHeadOfficeLatitude: result.coordinate?.latitude,
      businessHeadOfficeLongitude: result.coordinate?.longitude,
    );
    await AuthSession.instance.updateCorporateProfile(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('사업자 본사(소재지) 주소가 저장되었습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    await AuthSession.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.memberGateway,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final user = AuthSession.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text(
          '내정보 관리',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (!_hasHeadOffice) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '사업자 본사(소재지) 주소를 등록해야 공고를 올릴 수 있습니다. '
                      '아래에서 주소를 검색해 저장해 주세요.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.companyName ?? user?.name ?? '기업회원',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
                if (profile != null) ...[
                  const SizedBox(height: 12),
                  _InfoLine(
                    label: '담당자',
                    value: '${profile.department} · ${profile.contactPersonName}',
                  ),
                  _InfoLine(
                    label: '담당자 코드',
                    value: profile.handlerCode,
                  ),
                  _InfoLine(
                    label: '사업자등록번호',
                    value: profile.businessRegistrationNumber,
                  ),
                  _InfoLine(
                    label: '사업자 검증',
                    value: profile.verificationStatus.label,
                    valueColor: profile.verificationStatus ==
                            BusinessVerificationStatus.verified
                        ? AppColors.primary
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          CorporateSurfaceCard(
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporateShuttleAttendanceHub),
            child: const Row(
              children: [
                Icon(Icons.fact_check_outlined, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '셔틀·근태 관리',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '노선 · 지원 승인 · 출퇴근 · QR코드',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporatePaymentManagement),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '결제 관리',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ProductFeatureFlags.isHiringCommissionEnabled
                            ? '수수료 · 결제 권한 · 담당자 위임'
                            : '결제 권한 · 담당자 위임',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporateShuttleRoutes),
            child: const Row(
              children: [
                Icon(Icons.directions_bus_outlined, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '셔틀 노선 관리',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '통근 버스 경로 등록·공고 연결',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '사업장 · 주소',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _editHeadOffice,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        color: _hasHeadOffice
                            ? AppColors.primary
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '사업자 본사(소재지) 주소',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasHeadOffice
                                  ? profile!.businessHeadOfficeAddress!
                                  : '미등록 · 탭하여 주소 검색',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: _hasHeadOffice
                                    ? AppColors.textSecondary
                                        .withValues(alpha: 0.95)
                                    : Colors.orange.shade800,
                                fontWeight: _hasHeadOffice
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '지도 핀·공고 실근무지 검증의 기준이 됩니다.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppColors.searchBarBorder.withValues(alpha: 0.8),
                ),
                InkWell(
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppRoutes.corporateShuttleRoutes),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_bus_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '통근버스 노선 등록하기',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CorporateSurfaceCard(
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporateBranchManagement),
            child: Row(
              children: [
                const Icon(Icons.store_mall_directory_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '지점 · 매장 관리',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '본사 외 지점 주소 · 공고 연동',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '계정',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          if (profile == null)
            CorporateSurfaceCard(
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.corporateProfileSetup),
              child: const Row(
                children: [
                  Icon(Icons.person_add_outlined, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '기업 프로필 등록하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: '로그아웃',
            onPressed: _logout,
            dark: false,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
