import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

/// 공고 등록 — 근무지 무료 노출 안내 (유료 상품 노출 없음)
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
    final extraHubs = PushWalletCreditPolicy.registrationRecruitZoneCount(
      settings,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Row(
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
                const Text(
                  '근무지 주변 1km 무료 노출',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  extraHubs > 0
                      ? '일자리 알림핀 $extraHubs곳 설정됨'
                      : '공고 등록만으로 근무지 핀이 지도에 표시됩니다.',
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
    );
  }
}
