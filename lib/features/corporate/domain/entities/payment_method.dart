import 'package:flutter/material.dart';

/// PG 결제 수단 (실제 연동 시 PG사별 코드로 매핑)
enum PaymentMethod {
  naverPay,
  kakaoPay,
  payco,
  card,
  tossPay,
  bankTransfer,
}

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.naverPay => '네이버페이',
        PaymentMethod.kakaoPay => '카카오페이',
        PaymentMethod.payco => 'PAYCO',
        PaymentMethod.card => '신용·체크카드',
        PaymentMethod.tossPay => '토스페이',
        PaymentMethod.bankTransfer => '계좌이체',
      };

  String get subtitle => switch (this) {
        PaymentMethod.naverPay => '네이버페이 머니·포인트',
        PaymentMethod.kakaoPay => '카카오페이 머니·카드',
        PaymentMethod.payco => 'PAYCO 포인트·카드',
        PaymentMethod.card => '국내 모든 카드',
        PaymentMethod.tossPay => '토스페이 간편결제',
        PaymentMethod.bankTransfer => '실시간 계좌이체',
      };

  IconData get icon => switch (this) {
        PaymentMethod.naverPay => Icons.eco_rounded,
        PaymentMethod.kakaoPay => Icons.chat_bubble_rounded,
        PaymentMethod.payco => Icons.payments_rounded,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.tossPay => Icons.account_balance_wallet_rounded,
        PaymentMethod.bankTransfer => Icons.account_balance_rounded,
      };

  /// PG 연동 시 사용할 수단 코드 (예: 토스페이먼츠 `CARD`, `KAKAOPAY` 등)
  String get pgProviderCode => switch (this) {
        PaymentMethod.naverPay => 'NAVERPAY',
        PaymentMethod.kakaoPay => 'KAKAOPAY',
        PaymentMethod.payco => 'PAYCO',
        PaymentMethod.card => 'CARD',
        PaymentMethod.tossPay => 'TOSSPAY',
        PaymentMethod.bankTransfer => 'TRANSFER',
      };
}
