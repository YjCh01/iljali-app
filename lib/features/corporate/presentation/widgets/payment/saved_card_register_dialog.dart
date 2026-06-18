import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';

Future<SavedPaymentMethodDraft?> showSavedCardRegisterDialog(
  BuildContext context,
) {
  return showDialog<SavedPaymentMethodDraft>(
    context: context,
    builder: (context) => const _SavedCardRegisterDialog(),
  );
}

class SavedPaymentMethodDraft {
  const SavedPaymentMethodDraft({
    required this.cardBrand,
    required this.last4,
  });

  final String cardBrand;
  final String last4;
}

class _SavedCardRegisterDialog extends StatefulWidget {
  const _SavedCardRegisterDialog();

  @override
  State<_SavedCardRegisterDialog> createState() => _SavedCardRegisterDialogState();
}

class _SavedCardRegisterDialogState extends State<_SavedCardRegisterDialog> {
  static const _brands = ['신한', 'KB국민', '삼성', '현대', '롯데', 'BC', 'NH농협'];
  String _brand = '신한';
  final _last4Controller = TextEditingController();

  @override
  void dispose() {
    _last4Controller.dispose();
    super.dispose();
  }

  void _submit() {
    final last4 = _last4Controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (last4.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카드 번호 뒤 4자리를 입력해 주세요.')),
      );
      return;
    }
    Navigator.of(context).pop(
      SavedPaymentMethodDraft(cardBrand: _brand, last4: last4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('카드 등록'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PG 연동 전 MVP — 카드 뒤 4자리와 브랜드만 저장합니다.\n'
            '실제 카드번호·CVC는 PG 화면에서만 입력됩니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _brand,
            decoration: const InputDecoration(
              labelText: '카드사',
              border: OutlineInputBorder(),
            ),
            items: _brands
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _brand = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _last4Controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '카드 번호 뒤 4자리',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('등록'),
        ),
      ],
    );
  }
}
