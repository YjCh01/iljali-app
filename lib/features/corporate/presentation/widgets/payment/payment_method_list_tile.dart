import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';

/// Naver Pay 스타일 결제수단 행 — 좌측 라디오, 로고, 이름·설명
class PaymentMethodListTile extends StatelessWidget {
  const PaymentMethodListTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _SelectionIndicator(selected: selected),
              const SizedBox(width: 14),
              _PaymentBrandLogo(option: option),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    if (option.description != null &&
                        option.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        option.description!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 16,
          color: Colors.white,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.searchBarBorder,
          width: 1.5,
        ),
      ),
    );
  }
}

class _PaymentBrandLogo extends StatelessWidget {
  const _PaymentBrandLogo({required this.option});

  final PaymentMethodOption option;

  @override
  Widget build(BuildContext context) {
    if (option.logoAssetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          option.logoAssetPath!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _PlaceholderLogo(option: option),
        ),
      );
    }

    return _PlaceholderLogo(option: option);
  }
}

class _PlaceholderLogo extends StatelessWidget {
  const _PlaceholderLogo({required this.option});

  final PaymentMethodOption option;

  @override
  Widget build(BuildContext context) {
    final color = option.brandColor ?? AppColors.primary;
    final initials = option.brandInitials ?? option.label.characters.first;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: option.icon != null
          ? Icon(option.icon, size: 22, color: color)
          : Text(
              initials,
              style: TextStyle(
                fontSize: initials.length > 2 ? 10 : 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
    );
  }
}
