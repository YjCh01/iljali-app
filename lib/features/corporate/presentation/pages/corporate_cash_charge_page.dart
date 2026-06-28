import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/employer_cash_balance_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';

/// 보유금 선충전 — 결제 시 우선 차감
class CorporateCashChargePage extends StatefulWidget {
  const CorporateCashChargePage({super.key});

  @override
  State<CorporateCashChargePage> createState() =>
      _CorporateCashChargePageState();
}

class _CorporateCashChargePageState extends State<CorporateCashChargePage> {
  int _selectedAmount = EmployerCashBalanceService.presetAmountsKrw.first;
  PaymentMethod _method = PaymentMethodCatalog.defaultMethod;
  bool _processing = false;
  int _balanceKrw = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() => _balanceKrw = wallet.cashBalanceKrw);
  }

  Future<void> _charge() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null || _processing) return;

    setState(() => _processing = true);
    try {
      await EmployerCashBalanceService().charge(
        context: context,
        profile: profile,
        amountKrw: _selectedAmount,
        method: _method,
      );
      if (!mounted) return;
      await _loadBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '보유금 ${EmployerPushWallet(cashBalanceKrw: _balanceKrw).cashBalanceLabel} 충전 완료',
          ),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'minimum_charge' => '최소 충전 금액은 10,000원입니다.',
        _ => '충전에 실패했습니다. 다시 시도해 주세요.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceLabel =
        EmployerPushWallet(cashBalanceKrw: _balanceKrw).cashBalanceLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text(
          '보유금 충전',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 보유금',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$balanceLabel원',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '알림핀·표시핀·PUSH 결제 시 보유금이 먼저 차감됩니다. '
                  '부족분만 카드·간편결제로 청구됩니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '충전 금액',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in EmployerCashBalanceService.presetAmountsKrw)
                ChoiceChip(
                  label: Text(PushPackageCatalog.krwSuffix(amount)),
                  selected: _selectedAmount == amount,
                  onSelected: (_) => setState(() => _selectedAmount = amount),
                ),
            ],
          ),
          const SizedBox(height: 20),
          PaymentMethodSelectionSection(
            selectedMethod: _method,
            onMethodSelected: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _processing ? null : _charge,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '${PushPackageCatalog.krwSuffix(_selectedAmount)} 충전',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
