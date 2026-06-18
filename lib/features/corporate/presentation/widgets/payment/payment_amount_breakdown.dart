import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 결제 금액 내역 한 줄
class PaymentBreakdownLine {
  const PaymentBreakdownLine({
    required this.label,
    required this.amountKrw,
    this.isDiscount = false,
    this.emphasized = false,
  });

  final String label;
  final int amountKrw;
  final bool isDiscount;
  final bool emphasized;
}

String formatKrw(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

/// 하단 고정 결제 금액 요약 — 총 결제금액 + 상세 내역 (+ 결제 버튼)
class PaymentAmountBreakdown extends StatelessWidget {
  const PaymentAmountBreakdown({
    super.key,
    required this.lines,
    required this.totalKrw,
    this.totalLabel = '총 결제금액',
    this.action,
  });

  final List<PaymentBreakdownLine> lines;
  final int totalKrw;
  final String totalLabel;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.searchBarBorder),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in lines) ...[
                _BreakdownRow(line: line),
                const SizedBox(height: 8),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: AppColors.searchBarBorder),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      totalLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${formatKrw(totalKrw)}원',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 14),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.line});

  final PaymentBreakdownLine line;

  @override
  Widget build(BuildContext context) {
    final prefix = line.isDiscount ? '- ' : '';
    final formatted = formatKrw(line.amountKrw.abs());
    final valueColor = line.isDiscount
        ? const Color(0xFFE53935)
        : (line.emphasized ? AppColors.textPrimary : AppColors.textSecondary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          line.label,
          style: TextStyle(
            fontSize: line.emphasized ? 14 : 13,
            fontWeight: line.emphasized ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '$prefix$formatted원',
          style: TextStyle(
            fontSize: line.emphasized ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
