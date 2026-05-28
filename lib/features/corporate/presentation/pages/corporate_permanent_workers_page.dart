import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/local_permanent_employment_repository.dart';
import 'package:map/core/hiring/monthly_commission.dart';
import 'package:map/core/hiring/permanent_commission_calculator.dart';
import 'package:map/core/hiring/permanent_commission_sync_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/hiring/presentation/widgets/permanent_commission_payment_dialog.dart';

/// 기업 — 상시직 재직자·예상 수수료·청구 예정일
class CorporatePermanentWorkersPage extends StatefulWidget {
  const CorporatePermanentWorkersPage({super.key});

  @override
  State<CorporatePermanentWorkersPage> createState() =>
      _CorporatePermanentWorkersPageState();
}

class _CorporatePermanentWorkersPageState
    extends State<CorporatePermanentWorkersPage> {
  bool _loading = true;
  List<PermanentCommissionDashboardRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile ??
        await AuthSession.instance.ensureCorporateProfile();
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    await PermanentCommissionSyncService().pullForCompany(
      companyKey: profile.companyKey,
      companyName: profile.companyName,
    );

    final repo = await LocalPermanentEmploymentRepository.create();
    await repo.processDueBillingCycles();
    final rows = await repo.buildDashboardRows(
      companyKey: profile.companyKey,
      now: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _payCommission(
    PermanentCommissionDashboardRow row,
    MonthlyCommission commission,
  ) async {
    final paid = await showPermanentCommissionPaymentDialog(
      context,
      employment: row.employment,
      commission: commission,
    );
    if (paid == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('상시직 재직자'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '월급의 5.5% · 30일 주기 청구',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_rows.isEmpty)
                    CorporateSurfaceCard(
                      child: Text(
                        '상시직 합격 등록 후 재직자가 표시됩니다.',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    )
                  else
                    ..._rows.map((row) {
                      final employment = row.employment;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CorporateSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employment.seekerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '입사 ${DateFormat('yyyy.MM.dd').format(employment.hireDate)} · '
                                '월급 ${PermanentCommissionCalculator.formatKrw(employment.monthlySalaryKrw)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: '예상 수수료(5.5%)',
                                value: PermanentCommissionCalculator.formatKrw(
                                  row.expectedCommissionKrw,
                                ),
                                highlight: true,
                              ),
                              _InfoRow(
                                label: '다음 청구 예정일',
                                value: DateFormat('yyyy.MM.dd')
                                    .format(row.nextBillingAt),
                              ),
                              _InfoRow(
                                label: '완료 주기',
                                value: '${row.completedCycles}회',
                              ),
                              if (row.pendingCommissions.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...row.pendingCommissions.map(
                                  (commission) => Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '결제 대기 · '
                                            '${DateFormat('yyyy.MM.dd').format(commission.periodEnd)} · '
                                            '${PermanentCommissionCalculator.formatKrw(commission.amountKrw)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () =>
                                              _payCommission(row, commission),
                                          child: const Text('결제'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (row.recentCommissions.any(
                                (item) =>
                                    item.status == MonthlyCommissionStatus.charged,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '최근 청구: '
                                    '${row.recentCommissions.where((item) => item.status == MonthlyCommissionStatus.charged).map((item) => PermanentCommissionCalculator.formatKrw(item.amountKrw)).join(', ')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              if (row.needsInitialVerification)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '건강보험 인증 대기 중 — 해당 월 수수료 미청구 가능',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              if (row.needsReauthSoon)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '인증 만료 5일 전 — 구직자 재인증 안내 발송됨',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
