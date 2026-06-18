import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/trust/local_company_rating_repository.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/services/roi_pdf_service.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/roi_period.dart';
import 'package:map/features/corporate/domain/services/roi_metrics_service.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:printing/printing.dart';

/// 채용 ROI 대시보드 — 성과·비용 중심 (절감액은 관리자 협력사 모니터링 전용)
class CorporateRoiDashboardPage extends StatefulWidget {
  const CorporateRoiDashboardPage({super.key});

  @override
  State<CorporateRoiDashboardPage> createState() =>
      _CorporateRoiDashboardPageState();
}

class _CorporateRoiDashboardPageState extends State<CorporateRoiDashboardPage> {
  RoiMetrics? _metrics;
  List<BranchRoiRow> _branchRows = [];
  String _ratingSummary = '평가 없음';
  bool _loading = true;
  RoiPeriod _period = RoiPeriod.days30;

  PremiumPartnershipTier get _tier =>
      AuthSession.instance.currentUser?.corporateProfile?.partnershipTier ??
      PremiumPartnershipTier.basic;

  bool get _isEnterpriseTier =>
      _tier == PremiumPartnershipTier.enterprise ||
      AuthSession.instance.currentUser?.corporateProfile?.isEnterpriseOutsourcing ==
          true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    final metrics = await RoiMetricsService().computeForCompany(
      companyKey: profile.companyKey,
      tier: profile.partnershipTier,
      subscriptionActive: profile.hasActivePaidSubscription,
      period: _period,
    );
    final branchRows = await RoiMetricsService().computeBranchBreakdown(
      companyKey: profile.companyKey,
      tier: profile.partnershipTier,
      period: _period,
    );
    final ratingRepo = await LocalCompanyRatingRepository.create();
    final rating = await ratingRepo.summarizeCompany(profile.companyKey);

    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _branchRows = branchRows;
      _ratingSummary = rating.displayStars;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final metrics = _metrics;
    if (profile == null || metrics == null || !metrics.hasActivity) return;

    final bytes = await const RoiPdfService().buildPdf(
      companyName: profile.companyName,
      metrics: metrics,
      tierLabel: profile.partnershipTier.label,
      branchRows: _branchRows,
    );
    if (!mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  String _formatKrw(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('ROI 대시보드'),
        actions: [
          IconButton(
            onPressed: metrics?.hasActivity == true ? _exportPdf : null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF 내보내기',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : metrics == null
              ? const Center(child: Text('기업 프로필이 필요합니다.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _PeriodSelector(
                        selected: _period,
                        onChanged: (period) {
                          setState(() => _period = period);
                          _load();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!metrics.hasActivity)
                        _EmptyRoiGuide(onCreateJob: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.corporateCreateJobPost)
                              .then((_) => _load());
                        })
                      else ...[
                        _HeroSummaryCard(metrics: metrics),
                        const SizedBox(height: 12),
                        CorporateSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metrics.periodLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                metrics.summaryLine,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _MetricRow(
                                label: '지원',
                                value: '${metrics.applications}건',
                              ),
                              _MetricRow(
                                label: '출근 확인',
                                value: metrics.hasCheckIns
                                    ? '${metrics.checkIns}건'
                                    : '— (아직 없음)',
                              ),
                              _MetricRow(
                                label: '총 채용 비용',
                                value: metrics.totalSpendKrw > 0
                                    ? '${_formatKrw(metrics.totalSpendKrw)}원'
                                    : '—',
                              ),
                              if (metrics.hasMeaningfulRoi)
                                _MetricRow(
                                  label: '투자 대비 효율',
                                  value:
                                      '${metrics.roiPercent.toStringAsFixed(0)}%',
                                  hint:
                                      '추정 인건비 가치 대비 채용 비용 (참고 지표)',
                                ),
                              _MetricRow(
                                label: '구직자 평가',
                                value: _ratingSummary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        CorporateSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '비용 breakdown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ProductFeatureFlags.isHiringCommissionEnabled
                                    ? 'PUSH·구독·출근 수수료를 합산한 실제 지출입니다.'
                                    : 'PUSH·구독 등 노출·도달 유료 서비스 지출입니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _MetricRow(
                                label: 'PUSH',
                                value: metrics.pushSpendKrw > 0
                                    ? '${_formatKrw(metrics.pushSpendKrw)}원'
                                    : '—',
                              ),
                              _MetricRow(
                                label: '파트너십',
                                value: metrics.subscriptionSpendKrw > 0
                                    ? '${_formatKrw(metrics.subscriptionSpendKrw)}원'
                                    : '—',
                              ),
                              if (ProductFeatureFlags.isHiringCommissionEnabled)
                                _MetricRow(
                                  label: '출근 수수료',
                                  value: metrics.commissionSpendKrw > 0
                                      ? '${_formatKrw(metrics.commissionSpendKrw)}원'
                                      : '—',
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _MultiBranchSection(
                        isEnterprise: _isEnterpriseTier,
                        branchRows: _branchRows,
                        periodLabel: metrics.periodLabel,
                        onManageBranches: () => Navigator.of(context)
                            .pushNamed(AppRoutes.corporateBranchManagement)
                            .then((_) => _load()),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final RoiPeriod selected;
  final ValueChanged<RoiPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '채용 성과를 얼마나 돌아볼까요?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<RoiPeriod>(
          segments: RoiPeriod.values
              .map(
                (p) => ButtonSegment(
                  value: p,
                  label: Text(p.label, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          selected: {selected},
          onSelectionChanged: (set) => onChanged(set.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _EmptyRoiGuide extends StatelessWidget {
  const _EmptyRoiGuide({required this.onCreateJob});

  final VoidCallback onCreateJob;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 12),
          const Text(
            '아직 출근 데이터가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '공고를 등록하고 사람을 뽑아 보세요.\n'
            '지원 → 출근 확인이 쌓이면 비용과 효율이 여기에 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateJob,
            icon: const Icon(Icons.add_rounded),
            label: const Text('공고 등록하기'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({required this.metrics});

  final RoiMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primaryLight.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '채용 활동 요약',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metrics.hasCheckIns
                ? '출근 ${metrics.checkIns}건 · 지원 ${metrics.applications}건'
                : '지원 ${metrics.applications}건 · 출근 확인을 기다리는 중',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metrics.hasCheckIns
                ? '${metrics.periodLabel} 동안 채용 비용 '
                    '${metrics.totalSpendKrw.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원'
                : '출근이 확인되면 총 비용·효율 지표가 계산됩니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiBranchSection extends StatelessWidget {
  const _MultiBranchSection({
    required this.isEnterprise,
    required this.branchRows,
    required this.periodLabel,
    required this.onManageBranches,
  });

  final bool isEnterprise;
  final List<BranchRoiRow> branchRows;
  final String periodLabel;
  final VoidCallback onManageBranches;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      onTap: onManageBranches,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Multi-지점 ROI',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isEnterprise)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Enterprise',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEnterprise
                ? '본사에서 모든 지점의 공고·출근·비용을 한눈에 확인할 수 있습니다. '
                    '$periodLabel 기준으로 집계됩니다.'
                : '공고 노출 범위·지점은 패키지로 추가할 수 있습니다. '
                    '아웃소싱(Enterprise) 승인 기업은 본사·지역·매장 계층별 '
                    'ROI를 통합 관리할 수 있습니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          if (branchRows.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...branchRows.map((row) => _BranchRoiTile(row: row)),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isEnterprise
                    ? '등록된 지점이 없습니다. 지점 관리에서 본사·매장을 추가해 주세요.'
                    : '지점을 등록하면 지점별 공고·출근 실적을 볼 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '지점 관리 →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchRoiTile extends StatelessWidget {
  const _BranchRoiTile({required this.row});

  final BranchRoiRow row;

  String _krw(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row.levelLabel} · ${row.branchName}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _BranchStatChip(label: '공고', value: '${row.jobPostCount}'),
              _BranchStatChip(label: '지원', value: '${row.applications}'),
              _BranchStatChip(
                label: '출근',
                value: row.checkIns > 0 ? '${row.checkIns}' : '—',
              ),
              _BranchStatChip(
                label: '비용',
                value: row.commissionSpendKrw > 0
                    ? '${_krw(row.commissionSpendKrw)}원'
                    : '—',
              ),
              if (ProductFeatureFlags.isHiringCommissionEnabled &&
                  row.savingsVsBasicKrw > 0 &&
                  row.checkIns > 0)
                _BranchStatChip(
                  label: '플랜 절감',
                  value: '${_krw(row.savingsVsBasicKrw)}원',
                  highlight: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchStatChip extends StatelessWidget {
  const _BranchStatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryLight.withValues(alpha: 0.25)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.searchBarBorder,
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: highlight ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.hint,
  });

  final String label;
  final String value;
  final bool highlight;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                    color: highlight ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 120, top: 2),
              child: Text(
                hint!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
