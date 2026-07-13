import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

/// 기업 선충전 보유금 — 충전·차감·결제 연동
class EmployerCashBalanceService {
  EmployerCashBalanceService({PushWalletService? walletService})
      : _walletService = walletService ?? PushWalletService();

  final PushWalletService _walletService;

  static const presetAmountsKrw = [50000, 100000, 300000, 500000];

  Future<int> loadBalance(CorporateMemberProfile profile) async {
    final wallet = await _walletService.loadWallet(profile);
    return wallet.cashBalanceKrw;
  }

  Future<EmployerPushWallet> charge({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required int amountKrw,
    PaymentMethod method = PaymentMethod.card,
  }) async {
    final orderId = 'CASH-${DateTime.now().millisecondsSinceEpoch}';
    final request = PaymentRequest(
      orderId: orderId,
      productName: '보유금 충전',
      amountKrw: amountKrw,
      method: method,
      buyerEmail: AuthSession.instance.currentUser?.email,
      buyerName: AuthSession.instance.currentUser?.name,
      companyKey: profile.companyKey,
    );

    final flow = PaymentFlowHelper();
    final result = await flow.pay(context, request, allowCashBalance: false);
    if (!result.success) {
      throw StateError(result.message ?? 'charge_failed');
    }

    return _addBalance(profile, amountKrw);
  }

  Future<EmployerPushWallet> _addBalance(
    CorporateMemberProfile profile,
    int amountKrw,
  ) async {
    final wallet = await _walletService.loadWallet(profile);
    final next = wallet.copyWith(
      cashBalanceKrw: wallet.cashBalanceKrw + amountKrw,
    );
    await _walletService.persistWallet(profile, next);
    return next;
  }

  /// 결제 금액에서 보유금 우선 차감. 잔액 PG 결제 필요 시 [CashPayAttempt.remainingKrw].
  Future<CashPayAttempt> tryPayWithBalance({
    required CorporateMemberProfile profile,
    required int amountKrw,
  }) async {
    if (amountKrw <= 0) {
      return CashPayAttempt(
        success: true,
        usedCashKrw: 0,
        remainingKrw: 0,
      );
    }

    final wallet = await _walletService.loadWallet(profile);
    final usable = wallet.cashBalanceKrw.clamp(0, amountKrw);
    if (usable <= 0) {
      return CashPayAttempt(
        success: false,
        usedCashKrw: 0,
        remainingKrw: amountKrw,
      );
    }

    final next = wallet.copyWith(cashBalanceKrw: wallet.cashBalanceKrw - usable);
    await _walletService.persistWallet(profile, next);

    final remaining = amountKrw - usable;
    return CashPayAttempt(
      success: remaining <= 0,
      usedCashKrw: usable,
      remainingKrw: remaining,
    );
  }

  Future<void> openChargePage(BuildContext context) {
    return Navigator.of(context).pushNamed(AppRoutes.corporateCashCharge);
  }
}

class CashPayAttempt {
  const CashPayAttempt({
    required this.success,
    required this.usedCashKrw,
    required this.remainingKrw,
  });

  final bool success;
  final int usedCashKrw;
  final int remainingKrw;
}
