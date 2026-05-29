import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

/// 공고 등록 — 무료 등록 + 하루 1회 무료 푸시 안내
class PushRegistrationCostBanner extends StatelessWidget {
  const PushRegistrationCostBanner({
    super.key,
    required this.settings,
    required this.wallet,
  });

  final JobPostNotificationSettings settings;
  final EmployerPushWallet wallet;

  @override
  Widget build(BuildContext context) {
    final cost = PushWalletCreditPolicy.registrationCost(
      settings: settings,
      wallet: wallet,
    );
    final recruitZones = cost.configuredRecruitZones;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cost.formPreviewLine,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: AppColors.textPrimary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recruitZones > 0
                          ? '추가 모집지역 $recruitZones곳 — 모집하기 시 지역 푸시권 1회/곳'
                          : '등록 후 「모집하기」로 근무지 ${PushPackageCatalog.pushRadiusLabel} 푸시를 보낼 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.corporatePushPackageShop,
                );
              },
              child: const Text('지역 푸시권 보기'),
            ),
          ),
        ],
      ),
    );
  }
}
