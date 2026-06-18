import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';

/// Checkout — 저장 카드 선택 (없으면 숨김)
class SavedCardCheckoutSection extends StatelessWidget {
  const SavedCardCheckoutSection({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.onCardSelected,
    required this.useOtherMethod,
    required this.onUseOtherMethodChanged,
    this.enabled = true,
  });

  final List<SavedPaymentMethod> cards;
  final String? selectedCardId;
  final ValueChanged<String?> onCardSelected;
  final bool useOtherMethod;
  final ValueChanged<bool> onUseOtherMethodChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '저장된 카드',
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
              for (var i = 0; i < cards.length; i++) ...[
                RadioListTile<String>(
                  value: cards[i].id,
                  groupValue: useOtherMethod ? null : selectedCardId,
                  onChanged: enabled
                      ? (value) {
                          onUseOtherMethodChanged(false);
                          onCardSelected(value);
                        }
                      : null,
                  title: Text(
                    cards[i].displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: cards[i].isDefault
                      ? const Text('기본 결제수단')
                      : null,
                  secondary: const Icon(Icons.credit_card_rounded),
                ),
                if (i < cards.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              const Divider(height: 1),
              SwitchListTile(
                value: useOtherMethod,
                onChanged: enabled ? onUseOtherMethodChanged : null,
                title: const Text(
                  '다른 결제수단 사용',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
