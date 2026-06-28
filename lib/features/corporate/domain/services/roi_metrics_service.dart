import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/metrics/data/metrics_api_client.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/data/repositories/local_branch_repository.dart';
import 'package:map/features/corporate/data/repositories/local_push_usage_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_branch.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/roi_period.dart';

/// ROI 대시보드 집계 — 제휴 채널 수수료 대비 절감(활성 시) · PUSH 비용
class RoiMetrics {
  const RoiMetrics({
    required this.periodLabel,
    required this.pushSpendKrw,
    required this.subscriptionSpendKrw,
    required this.commissionSpendKrw,
    required this.totalSpendKrw,
    required this.applications,
    required this.checkIns,
    required this.estimatedLaborValueKrw,
    required this.roiPercent,
    required this.baselineCommissionPerCheckInKrw,
    required this.baselineCommissionTotalKrw,
    required this.commissionSavingsVsBasicKrw,
    required this.tierCommissionPerCheckInKrw,
    required this.estimatedCommissionAtTierKrw,
  });

  /// ROI 비교용 레거시 기준선 (제휴 채널 수수료·아웃소싱 대체 비교). 메인 앱 청구액 아님.
  static const baselineDailyCheckInFeeKrw = 15000;

  @Deprecated('Use baselineDailyCheckInFeeKrw')
  static const basicLegacyCommissionKrw = baselineDailyCheckInFeeKrw;

  final String periodLabel;
  final int pushSpendKrw;
  final int subscriptionSpendKrw;
  final int commissionSpendKrw;
  final int totalSpendKrw;
  final int applications;
  final int checkIns;
  final int estimatedLaborValueKrw;
  final double roiPercent;
  final int baselineCommissionPerCheckInKrw;
  final int baselineCommissionTotalKrw;
  final int commissionSavingsVsBasicKrw;
  final int tierCommissionPerCheckInKrw;
  final int estimatedCommissionAtTierKrw;

  String get summaryLine => hasCheckIns
      ? '출근 $checkIns건 · 채용 비용 ${_formatKrw(totalSpendKrw)}'
      : '지원 $applications건 · 출근 데이터를 모으는 중';

  String get savingsHeadline => commissionSavingsVsBasicKrw > 0
      ? '제휴 수수료 기준 대비 ${_formatKrw(commissionSavingsVsBasicKrw)} 절약'
      : '출근 $checkIns건 · 비용 ${_formatKrw(commissionSpendKrw)}';

  bool get hasActivity =>
      applications > 0 || checkIns > 0 || totalSpendKrw > 0;

  bool get hasCheckIns => checkIns > 0;

  bool get hasMeaningfulRoi => hasCheckIns && totalSpendKrw > 0;

  String get emptyStateHeadline => '아직 채용 성과 데이터가 없습니다';

  String get emptyStateGuide =>
      '공고를 등록하고 지원자를 받은 뒤, 출근 확인이 이뤄지면 '
      '비용·효율 지표가 이곳에 표시됩니다.';

  static String _formatKrw(int v) =>
      '${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}

class BranchRoiRow {
  const BranchRoiRow({
    required this.branchId,
    required this.branchName,
    required this.levelLabel,
    required this.jobPostCount,
    required this.applications,
    required this.checkIns,
    required this.commissionSpendKrw,
    required this.savingsVsBasicKrw,
  });

  final String branchId;
  final String branchName;
  final String levelLabel;
  final int jobPostCount;
  final int applications;
  final int checkIns;
  final int commissionSpendKrw;
  final int savingsVsBasicKrw;

  bool get hasActivity => applications > 0 || checkIns > 0 || jobPostCount > 0;

  String get summaryLine => hasActivity
      ? '공고 $jobPostCount · 지원 $applications · 출근 $checkIns · '
          '비용 ${RoiMetrics._formatKrw(commissionSpendKrw)}'
      : '아직 실적 없음 · 공고에 지점을 연결해 주세요';
}

class RoiMetricsService {
  Future<RoiMetrics> computeForCompany({
    required String companyKey,
    required PremiumPartnershipTier tier,
    required bool subscriptionActive,
    RoiPeriod period = RoiPeriod.days30,
    DateTime? since,
  }) async {
    final repo = await LocalHiringRepository.create();
    final apps = (await repo.fetchAll())
        .where((a) => a.companyKey == null || a.companyKey == companyKey)
        .toList();

    final from = since ?? period.sinceFrom(DateTime.now());
    final filtered = from == null
        ? apps
        : apps.where((a) => a.appliedAt.isAfter(from)).toList();

    var checkIns = 0;
    var commissionTotal = 0;
    for (final app in filtered) {
      if (app.status == HiringApplicationStatus.checkedIn ||
          app.status == HiringApplicationStatus.commissionPaid) {
        checkIns++;
      }
      if (app.commissionPaidAt != null && app.commissionAmountKrw != null) {
        commissionTotal += app.commissionAmountKrw!;
      }
    }

    final subscriptionSpend = 0;

    final postSource = const CorporateJobPostLocalDataSourceImpl();
    final posts = await postSource.fetchJobPosts();
    var pushSpendFromPosts = 0;
    for (final post in posts) {
      final record = post.paymentRecord;
      final key = post.registeredBy?.companyKey;
      if (record == null || key != companyKey) continue;
      if (from == null || record.paidAt.isAfter(from)) {
        pushSpendFromPosts += record.amountKrw;
      }
    }

    final pushUsageRepo = await LocalPushUsageRepository.create();
    final pushSpendFromUsage = from == null
        ? await pushUsageRepo.sumSpendSince(
            companyKey,
            DateTime.fromMillisecondsSinceEpoch(0),
          )
        : await pushUsageRepo.sumSpendSince(companyKey, from);
    final pushSpend = pushSpendFromPosts + pushSpendFromUsage;

    final tierFee = tier.dailyWorkerSuccessFeeKrwMin;
    final estimatedAtTier = ProductFeatureFlags.isHiringCommissionEnabled
        ? checkIns * tierFee
        : 0;
    final effectiveCommission =
        commissionTotal > 0 ? commissionTotal : estimatedAtTier;

    final baselineTotal = ProductFeatureFlags.isHiringCommissionEnabled
        ? checkIns * RoiMetrics.baselineDailyCheckInFeeKrw
        : 0;
    final savingsVsBasic = ProductFeatureFlags.isHiringCommissionEnabled
        ? baselineTotal - effectiveCommission
        : 0;

    final total = pushSpend + subscriptionSpend + effectiveCommission;
    const laborValuePerCheckIn = 120000;
    final laborValue = checkIns * laborValuePerCheckIn;
    final roi = total > 0 ? ((laborValue - total) / total) * 100 : 0.0;

    final localMetrics = RoiMetrics(
      periodLabel: period.label,
      pushSpendKrw: pushSpend,
      subscriptionSpendKrw: subscriptionSpend,
      commissionSpendKrw: effectiveCommission,
      totalSpendKrw: total,
      applications: filtered.length,
      checkIns: checkIns,
      estimatedLaborValueKrw: laborValue,
      roiPercent: roi,
      baselineCommissionPerCheckInKrw: RoiMetrics.baselineDailyCheckInFeeKrw,
      baselineCommissionTotalKrw: baselineTotal,
      commissionSavingsVsBasicKrw: savingsVsBasic.clamp(0, 999999999),
      tierCommissionPerCheckInKrw: tierFee,
      estimatedCommissionAtTierKrw: estimatedAtTier,
    );

    if (checkIns == 0 && EnvConfig.isComplianceApiEnabled) {
      try {
        final map = await MetricsApiClient().fetchRoiSummaryRaw(
          companyKey: companyKey,
          tier: tier.name,
        );
        final tierFeeRemote =
            (map['tier_commission_per_check_in_krw'] as num?)?.toInt() ?? tierFee;
        final remoteCheckIns = map['check_ins'] as int? ?? 0;
        return RoiMetrics(
          periodLabel: map['period_label'] as String? ?? '최근 30일',
          pushSpendKrw: map['push_spend_krw'] as int? ?? 0,
          subscriptionSpendKrw: map['subscription_spend_krw'] as int? ?? 0,
          commissionSpendKrw: map['commission_spend_krw'] as int? ?? 0,
          totalSpendKrw: map['total_spend_krw'] as int? ?? 0,
          applications: map['applications'] as int? ?? 0,
          checkIns: remoteCheckIns,
          estimatedLaborValueKrw: map['estimated_labor_value_krw'] as int? ?? 0,
          roiPercent: (map['roi_percent'] as num?)?.toDouble() ?? 0,
          baselineCommissionPerCheckInKrw:
              map['baseline_commission_per_check_in_krw'] as int? ??
                  RoiMetrics.baselineDailyCheckInFeeKrw,
          baselineCommissionTotalKrw:
              map['baseline_commission_total_krw'] as int? ?? 0,
          commissionSavingsVsBasicKrw:
              map['commission_savings_vs_basic_krw'] as int? ?? 0,
          tierCommissionPerCheckInKrw: tierFeeRemote,
          estimatedCommissionAtTierKrw: remoteCheckIns * tierFeeRemote,
        );
      } on MetricsApiException {
        // 로컬 결과 유지
      }
    }
    return localMetrics;
  }

  Future<List<BranchRoiRow>> computeBranchBreakdown({
    required String companyKey,
    required PremiumPartnershipTier tier,
    RoiPeriod period = RoiPeriod.days30,
    DateTime? since,
  }) async {
    final from = since ?? period.sinceFrom(DateTime.now());
    final tierFee = tier.dailyWorkerSuccessFeeKrwMin;

    final branchRepo = await LocalBranchRepository.create();
    final branches = await branchRepo.fetchForCompany(companyKey);
    if (branches.isEmpty) return [];

    final postSource = const CorporateJobPostLocalDataSourceImpl();
    final posts = await postSource.fetchJobPosts();
    final postBranch = <String, String>{};
    final postsPerBranch = <String, int>{};
    for (final post in posts) {
      if (post.registeredBy?.companyKey != null &&
          post.registeredBy!.companyKey != companyKey) {
        continue;
      }
      if (from != null && post.postedAt.isBefore(from)) continue;
      if (post.branchId != null) {
        postBranch[post.id] = post.branchId!;
        postsPerBranch.update(
          post.branchId!,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final hiringRepo = await LocalHiringRepository.create();
    final apps = (await hiringRepo.fetchAll()).where((a) {
      if (a.companyKey != null && a.companyKey != companyKey) return false;
      if (from != null && !a.appliedAt.isAfter(from)) return false;
      return true;
    }).toList();

    final grouped = <String, List<HiringApplication>>{
      for (final branch in branches) branch.id: [],
    };

    for (final app in apps) {
      final branchId =
          app.branchId ?? postBranch[app.postId] ?? '_unassigned';
      grouped.putIfAbsent(branchId, () => []).add(app);
    }

    final rows = <BranchRoiRow>[];
    for (final branch in branches) {
      final list = grouped[branch.id] ?? const <HiringApplication>[];
      var checkIns = 0;
      var commissionTotal = 0;
      for (final app in list) {
        if (app.status == HiringApplicationStatus.checkedIn ||
            app.status == HiringApplicationStatus.commissionPaid) {
          checkIns++;
        }
        if (app.commissionPaidAt != null && app.commissionAmountKrw != null) {
          commissionTotal += app.commissionAmountKrw!;
        }
      }
      final effectiveCommission = ProductFeatureFlags.isHiringCommissionEnabled
          ? (commissionTotal > 0 ? commissionTotal : checkIns * tierFee)
          : 0;
      final baseline = ProductFeatureFlags.isHiringCommissionEnabled
          ? checkIns * RoiMetrics.baselineDailyCheckInFeeKrw
          : 0;
      rows.add(
        BranchRoiRow(
          branchId: branch.id,
          branchName: branch.displayLabel,
          levelLabel: branch.level.label,
          jobPostCount: postsPerBranch[branch.id] ?? 0,
          applications: list.length,
          checkIns: checkIns,
          commissionSpendKrw: effectiveCommission,
          savingsVsBasicKrw: (baseline - effectiveCommission).clamp(0, 999999999),
        ),
      );
    }

    rows.sort((a, b) => b.savingsVsBasicKrw.compareTo(a.savingsVsBasicKrw));

    if (rows.every((r) => r.checkIns == 0) && EnvConfig.isComplianceApiEnabled) {
      try {
        final remote = await MetricsApiClient().fetchBranchRoiRaw(
          companyKey: companyKey,
          tier: tier.name,
        );
        return remote
            .map(
              (row) => BranchRoiRow(
                branchId: row['branch_name'] as String? ?? '',
                branchName: row['branch_name'] as String? ?? '',
                levelLabel: row['level_label'] as String? ?? '',
                jobPostCount: row['job_post_count'] as int? ?? 0,
                applications: row['applications'] as int? ?? 0,
                checkIns: row['check_ins'] as int? ?? 0,
                commissionSpendKrw: row['commission_spend_krw'] as int? ?? 0,
                savingsVsBasicKrw: row['savings_vs_basic_krw'] as int? ?? 0,
              ),
            )
            .toList();
      } on MetricsApiException {
        // 로컬 결과 유지
      }
    }
    return rows;
  }
}
