import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/compliance/contact_entitlement.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';

/// 파트너십 가입 유도 다이얼로그
Future<void> showPartnershipUpsellDialog(
  BuildContext context, {
  required String title,
  required String message,
  bool showTierCards = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (showTierCards) ...[
              const SizedBox(height: 16),
              const Text(
                '일자리 알림핀',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const PartnershipTierCards(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed(
              AppRoutes.corporatePushPackageShop,
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('일자리 알림핀 구매'),
        ),
      ],
    ),
  );
}

Future<bool> ensureContactAccess(
  BuildContext context,
  ContactAccessResult access,
) async {
  if (access.allowed) return true;
  await showPartnershipUpsellDialog(
    context,
    title: '연락 기능 제한',
    message: access.blockReason ?? '파트너십 가입이 필요합니다.',
    showTierCards: access.showPartnershipUpsell,
  );
  return false;
}
