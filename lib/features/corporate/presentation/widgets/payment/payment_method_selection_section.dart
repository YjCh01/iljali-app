import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_list_tile.dart';

/// 결제수단 선택 영역 — 접힌 기본값 + "다른 결제수단 선택" 패턴 지원
class PaymentMethodSelectionSection extends StatefulWidget {
  const PaymentMethodSelectionSection({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
    this.options,
    this.enabled = true,
    this.collapsibleDefault = true,
    this.title = '결제수단',
  });

  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onMethodSelected;
  final List<PaymentMethodOption>? options;
  final bool enabled;
  final bool collapsibleDefault;
  final String title;

  @override
  State<PaymentMethodSelectionSection> createState() =>
      _PaymentMethodSelectionSectionState();
}

class _PaymentMethodSelectionSectionState
    extends State<PaymentMethodSelectionSection> {
  bool _expanded = false;

  List<PaymentMethodOption> get _options =>
      widget.options ?? PaymentMethodCatalog.checkoutOptions;

  PaymentMethodOption _optionFor(PaymentMethod method) =>
      _options.firstWhere(
        (o) => o.method == method,
        orElse: () => PaymentMethodOption.fromMethod(method),
      );

  @override
  Widget build(BuildContext context) {
    final showCollapsed =
        widget.collapsibleDefault && !_expanded && widget.enabled;
    final visibleOptions = showCollapsed
        ? [_optionFor(widget.selectedMethod)]
        : _options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          color: AppColors.surface,
          child: Column(
            children: [
              for (var i = 0; i < visibleOptions.length; i++) ...[
                PaymentMethodListTile(
                  option: visibleOptions[i],
                  selected: widget.selectedMethod == visibleOptions[i].method,
                  onTap: widget.enabled
                      ? () {
                          widget.onMethodSelected(visibleOptions[i].method);
                          if (showCollapsed) {
                            setState(() => _expanded = false);
                          }
                        }
                      : null,
                ),
                if (i < visibleOptions.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 58,
                    color: AppColors.searchBarBorder,
                  ),
              ],
              if (showCollapsed) ...[
                const Divider(height: 1, color: AppColors.searchBarBorder),
                Material(
                  color: AppColors.surface,
                  child: InkWell(
                    onTap: widget.enabled
                        ? () => setState(() => _expanded = true)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '다른 결제수단 선택',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.textSecondary.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
