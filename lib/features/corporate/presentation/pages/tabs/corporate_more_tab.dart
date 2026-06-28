import 'package:flutter/material.dart';
import 'package:map/core/auth/guest_auth_navigation.dart';
import 'package:map/core/branding/iljari_ad_campaign.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/presentation/utils/corporate_shell_access.dart';
import 'package:map/features/corporate/data/repositories/corporate_tax_document_repository.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_service_guide_section.dart';
import 'package:map/core/legal/widgets/business_disclosure_footer.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_tax_documents_grid_section.dart';

/// 기업회원 6번 탭 — 내정보 · 계정 관리 (초기 MVP: 통계·예약 메뉴 제외)
class CorporateMoreTab extends StatefulWidget {
  const CorporateMoreTab({super.key});

  @override
  State<CorporateMoreTab> createState() => _CorporateMoreTabState();
}

class _CorporateMoreTabState extends State<CorporateMoreTab> {
  Map<TaxDocumentType, int> _taxDocCounts = {};

  @override
  void initState() {
    super.initState();
    AuthSession.instance.corporateProfileRevision.addListener(_onProfileChanged);
    _loadTaxDocCounts();
  }

  Future<void> _loadTaxDocCounts() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      if (!mounted) return;
      setState(() => _taxDocCounts = {});
      return;
    }
    final repo = await CorporateTaxDocumentRepository.create();
    final docs = await repo.listForCompany(profile.companyKey);
    final counts = <TaxDocumentType, int>{
      for (final type in TaxDocumentType.values) type: 0,
    };
    for (final doc in docs) {
      counts[doc.type] = (counts[doc.type] ?? 0) + 1;
    }
    if (!mounted) return;
    setState(() => _taxDocCounts = counts);
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision
        .removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {});
      _loadTaxDocCounts();
    }
  }

  bool get _needsHeadOffice {
    final addr = AuthSession.instance.currentUser?.corporateProfile
        ?.businessHeadOfficeAddress
        ?.trim();
    return addr == null || addr.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final user = AuthSession.instance.currentUser;
    final signedIn = CorporateShellAccess.isSignedInCorporate;

    if (!signedIn) {
      return ColoredBox(
        color: AppColors.background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const IljariAdCampaignBanner(),
            const SizedBox(height: 16),
            CorporateSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '로그인하고 채용을 시작하세요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => GuestAuthNavigation.openLogin(context),
                    child: const Text('로그인'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => GuestAuthNavigation.openSignUp(context),
                    child: const Text('회원가입'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const CorporateServiceGuideSection(),
            const SizedBox(height: 16),
            _MenuTile(
              icon: Icons.help_outline_rounded,
              title: '고객센터',
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.customerSupport,
              ),
            ),
            _MenuTile(
              icon: Icons.description_outlined,
              title: '약관 및 정책',
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.legalDocuments,
              ),
            ),
            const SizedBox(height: 16),
            const BusinessDisclosureFooter(),
          ],
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const IljariAdCampaignBanner(),
          const SizedBox(height: 20),
          const CorporateServiceGuideSection(),
          const SizedBox(height: 20),
          if (_needsHeadOffice) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Text(
                '사업자 본사(소재지) 주소를 등록해야 공고를 올릴 수 있습니다. '
                '「내정보 관리」에서 주소를 저장해 주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _SectionLabel('계정 · 사업장'),
          const SizedBox(height: 8),
          CorporateSurfaceCard(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.corporateMyInfo),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.35),
                  child: const Icon(Icons.business, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.companyName ?? user?.name ?? '기업회원',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile != null
                            ? '${profile.department} · ${profile.contactPersonName}'
                            : '프로필을 등록해 주세요',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.95),
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
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.person_outline_rounded,
            title: '내정보 관리',
            subtitle: _needsHeadOffice
                ? '사업자 본사 주소 등록 필요'
                : '담당자 · 소재지 · 검증 상태',
            highlight: _needsHeadOffice,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.corporateMyInfo),
          ),
          _HeadOfficeMenuCard(
            needsHeadOffice: _needsHeadOffice,
            address: profile?.businessHeadOfficeAddress,
            onEditAddress: () =>
                Navigator.of(context).pushNamed(AppRoutes.corporateMyInfo),
            onRegisterShuttle: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporateShuttleRoutes),
          ),
          _MenuTile(
            icon: Icons.store_mall_directory_outlined,
            title: 'Multi-지점 관리',
            subtitle: '본사 · 지역 · 매장 · 공고 연동',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporateBranchManagement),
          ),
          _MenuTile(
            icon: Icons.payments_outlined,
            title: '결제 관리',
            subtitle: ProductFeatureFlags.isHiringCommissionEnabled
                ? '수수료 결제 · 결제 권한 · 담당자 위임'
                : '결제 권한 · 담당자 위임',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporatePaymentManagement),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('서비스'),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.quickreply_outlined,
            title: '채팅 매크로',
            subtitle: '자주 쓰는 답변 등록 · 지원자 채팅에서 사용',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.corporateChatReplyMacros),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('결제 · 증빙'),
          const SizedBox(height: 8),
          CorporateTaxDocumentsGridSection(
            counts: _taxDocCounts,
            onRefresh: _loadTaxDocCounts,
          ),
          const SizedBox(height: 12),
          const _SectionLabel('고객 지원'),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            title: '고객센터',
            subtitle: 'FAQ · 문의 이메일',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.customerSupport),
          ),
          _MenuTile(
            icon: Icons.description_outlined,
            title: '약관 및 정책',
            subtitle: '이용약관 · 개인정보처리방침',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.legalDocuments),
          ),
          const SizedBox(height: 16),
          const BusinessDisclosureFooter(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: AppColors.textSecondary.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _HeadOfficeMenuCard extends StatelessWidget {
  const _HeadOfficeMenuCard({
    required this.needsHeadOffice,
    required this.address,
    required this.onEditAddress,
    required this.onRegisterShuttle,
  });

  final bool needsHeadOffice;
  final String? address;
  final VoidCallback onEditAddress;
  final VoidCallback onRegisterShuttle;

  @override
  Widget build(BuildContext context) {
    final subtitle = needsHeadOffice
        ? '미등록 — 공고 등록 전 필수'
        : address ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onEditAddress,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    color: needsHeadOffice
                        ? Colors.orange.shade800
                        : AppColors.primary,
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
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: needsHeadOffice
                                  ? Colors.orange.shade800
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.95),
                              fontWeight: needsHeadOffice
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
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
              onTap: onRegisterShuttle,
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
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              color: highlight ? Colors.orange.shade800 : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: highlight
                            ? Colors.orange.shade800
                            : AppColors.textSecondary.withValues(alpha: 0.95),
                        fontWeight:
                            highlight ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
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
    );
  }
}
