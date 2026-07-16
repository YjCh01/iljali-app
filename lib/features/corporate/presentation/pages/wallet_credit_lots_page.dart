import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/wallet_credit_lot.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 만료 예정 크레딧 상세 — 배치(lot)별 만료일 · 잔여량
class WalletCreditLotsPage extends StatefulWidget {
  const WalletCreditLotsPage({super.key});

  @override
  State<WalletCreditLotsPage> createState() => _WalletCreditLotsPageState();
}

class _WalletCreditLotsPageState extends State<WalletCreditLotsPage> {
  final _walletService = PushWalletService();
  List<WalletCreditLot> _lots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }
    final lots = await _walletService.fetchActiveLots(profile);
    if (!mounted) return;
    setState(() {
      _lots = lots;
      _loading = false;
    });
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
        title: const Text('만료 예정 크레딧'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '충전한 크레딧은 지급일로부터 180일간 유효합니다.\n'
                    '만료가 임박한 순서로 표시됩니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_lots.isEmpty)
                    const CorporateSurfaceCard(
                      child: Text(
                        '보유 중인 크레딧이 없습니다.',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                    )
                  else
                    for (final lot in _lots) ...[
                      _CreditLotCard(lot: lot),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class _CreditLotCard extends StatelessWidget {
  const _CreditLotCard({required this.lot});

  final WalletCreditLot lot;

  @override
  Widget build(BuildContext context) {
    final days = lot.daysUntilExpiry;
    final urgent = days != null && days <= 14;

    return CorporateSurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.creditTypeLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '잔여 ${lot.remaining}회',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          if (days != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: urgent
                    ? const Color(0xFFFFEBEE)
                    : AppColors.primaryLight.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                days <= 0 ? '오늘 만료' : 'D-$days',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: urgent ? const Color(0xFFC62828) : AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
