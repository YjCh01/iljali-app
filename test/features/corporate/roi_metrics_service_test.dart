import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/services/roi_metrics_service.dart';

void main() {
  group('RoiMetricsService', () {
    test('uses flat 10,000 won commission for all tiers', () async {
      final metrics = await RoiMetricsService().computeForCompany(
        companyKey: 'test_company',
        tier: PremiumPartnershipTier.starter,
        subscriptionActive: true,
      );

      expect(metrics.baselineCommissionPerCheckInKrw, 10000);
      expect(metrics.tierCommissionPerCheckInKrw, 10000);
      expect(metrics.commissionSavingsVsBasicKrw, 0);
    });

    test('savings headline shows spend when no tier savings', () async {
      final metrics = await RoiMetricsService().computeForCompany(
        companyKey: 'x',
        tier: PremiumPartnershipTier.growth,
        subscriptionActive: true,
      );
      if (metrics.checkIns > 0 && metrics.commissionSavingsVsBasicKrw == 0) {
        expect(metrics.savingsHeadline, contains('수수료'));
      }
    });

    test('branch breakdown returns empty when no branches', () async {
      final rows = await RoiMetricsService().computeBranchBreakdown(
        companyKey: 'no_branches_company',
        tier: PremiumPartnershipTier.enterprise,
      );
      expect(rows, isEmpty);
    });

    test('branch row summary includes applications and check-ins', () {
      const row = BranchRoiRow(
        branchId: 'b1',
        branchName: '강남센터',
        levelLabel: '매장',
        jobPostCount: 2,
        applications: 5,
        checkIns: 3,
        commissionSpendKrw: 30000,
        savingsVsBasicKrw: 0,
      );
      expect(row.summaryLine, contains('지원 5'));
      expect(row.summaryLine, contains('출근 3'));
    });
  });
}
