import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';

/// Checkout UI용 결제수단 옵션 — PG enum과 분리해 표시·브랜딩 확장
class PaymentMethodOption {
  const PaymentMethodOption({
    required this.method,
    required this.label,
    this.description,
    this.brandColor,
    this.brandInitials,
    this.logoAssetPath,
    this.icon,
  });

  final PaymentMethod method;
  final String label;
  final String? description;
  final Color? brandColor;
  final String? brandInitials;
  final String? logoAssetPath;
  final IconData? icon;

  factory PaymentMethodOption.fromMethod(PaymentMethod method) {
    return PaymentMethodCatalog.byMethod(method);
  }
}

/// 결제수단 목록 — 새 수단 추가 시 여기에 항목만 추가
abstract final class PaymentMethodCatalog {
  static const checkoutOrder = <PaymentMethod>[
    PaymentMethod.naverPay,
    PaymentMethod.kakaoPay,
    PaymentMethod.payco,
    PaymentMethod.card,
    PaymentMethod.tossPay,
    PaymentMethod.bankTransfer,
  ];

  static PaymentMethod get defaultMethod => PaymentMethod.naverPay;

  static List<PaymentMethodOption> get checkoutOptions =>
      checkoutOrder.map(byMethod).toList(growable: false);

  static PaymentMethodOption byMethod(PaymentMethod method) =>
      _options[method] ?? _fallback(method);

  static PaymentMethodOption _fallback(PaymentMethod method) {
    return PaymentMethodOption(
      method: method,
      label: method.label,
      description: method.subtitle,
      icon: method.icon,
    );
  }

  static const _options = <PaymentMethod, PaymentMethodOption>{
    PaymentMethod.naverPay: PaymentMethodOption(
      method: PaymentMethod.naverPay,
      label: '네이버페이',
      description: '네이버페이 머니·포인트',
      brandColor: Color(0xFF03C75A),
      brandInitials: 'N',
      icon: Icons.eco_rounded,
    ),
    PaymentMethod.kakaoPay: PaymentMethodOption(
      method: PaymentMethod.kakaoPay,
      label: '카카오페이',
      description: '카카오페이 머니·카드',
      brandColor: Color(0xFFFEE500),
      brandInitials: 'K',
      icon: Icons.chat_bubble_rounded,
    ),
    PaymentMethod.payco: PaymentMethodOption(
      method: PaymentMethod.payco,
      label: 'PAYCO',
      description: 'PAYCO 포인트·카드',
      brandColor: Color(0xFFFA2828),
      brandInitials: 'P',
      icon: Icons.payments_rounded,
    ),
    PaymentMethod.card: PaymentMethodOption(
      method: PaymentMethod.card,
      label: '신용·체크카드',
      description: '국내 모든 카드',
      brandColor: Color(0xFF5C6BC0),
      brandInitials: 'CARD',
      icon: Icons.credit_card_rounded,
    ),
    PaymentMethod.tossPay: PaymentMethodOption(
      method: PaymentMethod.tossPay,
      label: '토스페이',
      description: '토스페이 간편결제',
      brandColor: Color(0xFF0064FF),
      brandInitials: 'T',
      icon: Icons.account_balance_wallet_rounded,
    ),
    PaymentMethod.bankTransfer: PaymentMethodOption(
      method: PaymentMethod.bankTransfer,
      label: '계좌이체',
      description: '실시간 계좌이체',
      brandColor: Color(0xFF78909C),
      brandInitials: '계',
      icon: Icons.account_balance_rounded,
    ),
  };
}
