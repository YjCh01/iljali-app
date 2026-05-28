import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_plan_strip.dart';

/// 홈 탭 — 기본 vs 패키지 가로 스트립 (세로 배열)
class CorporateHomeFeatureHighlights extends StatefulWidget {
  const CorporateHomeFeatureHighlights({
    super.key,
    required this.onPushHiring,
    required this.onInstantMatching,
  });

  final VoidCallback onPushHiring;
  final VoidCallback onInstantMatching;

  @override
  State<CorporateHomeFeatureHighlights> createState() =>
      _CorporateHomeFeatureHighlightsState();
}

class _CorporateHomeFeatureHighlightsState
    extends State<CorporateHomeFeatureHighlights> {
  int? _quotaRemaining;
  int? _quotaMax;

  @override
  void initState() {
    super.initState();
    _loadQuota();
    AuthSession.instance.corporateProfileRevision.addListener(_onWalletChanged);
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision
        .removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onWalletChanged() => _loadQuota();

  Future<void> _loadQuota() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() {
      _quotaRemaining = wallet.jobPostRegistrationQuotaRemaining;
      _quotaMax = wallet.jobPostRegistrationQuotaMax;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BasicPlanStrip(
          onTap: widget.onPushHiring,
          quotaRemaining: _quotaRemaining,
          quotaMax: _quotaMax,
        ),
        const SizedBox(height: 10),
        _PackageBenefitStrip(onTap: widget.onInstantMatching),
      ],
    );
  }
}

class _BasicPlanStrip extends StatelessWidget {
  const _BasicPlanStrip({
    required this.onTap,
    this.quotaRemaining,
    this.quotaMax,
  });

  final VoidCallback onTap;
  final int? quotaRemaining;
  final int? quotaMax;

  String get _quotaLabel {
    if (quotaRemaining == null || quotaMax == null) {
      return '잔여 횟수 불러오는 중…';
    }
    return '남은 공고 등록 횟수 $quotaRemaining/$quotaMax';
  }

  @override
  Widget build(BuildContext context) {
    return CorporateHomePlanStrip(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '공고 등록 무료',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.searchBarBorder),
                      ),
                      child: Text(
                        PushPackageCatalog.defaultPlanLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const ActivePlanInUseBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _quotaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '등록 →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageBenefitStrip extends StatelessWidget {
  const _PackageBenefitStrip({required this.onTap});

  final VoidCallback onTap;

  static const _lightPurple = Color(0xFFF3EEFF);
  static const _lightPurpleBorder = Color(0xFFD4C4FF);

  @override
  Widget build(BuildContext context) {
    return CorporateHomePlanStrip(
      onTap: onTap,
      backgroundColor: _lightPurple,
      borderColor: _lightPurpleBorder,
      shadow: true,
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 26,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '공고 노출·모집 패키지',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '기본 대비 · +노출 +모집 · 지역 추가 · 100회팩 프리미엄 핀',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '구매 →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
