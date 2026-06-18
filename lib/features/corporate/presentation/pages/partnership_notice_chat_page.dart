import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';

/// PUSH 정책 공식 안내 채팅 상세
class PartnershipNoticeChatPage extends StatelessWidget {
  const PartnershipNoticeChatPage({
    super.key,
    required this.room,
  });

  final CorporateChatRoom room;

  @override
  Widget build(BuildContext context) {
    final body = room.fullMessageBody ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('일자리 운영팀'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'PUSH 정책 안내',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textPrimary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '요금제 요약',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const PartnershipTierCards(),
          const SizedBox(height: 16),
          Text(
            '※ 공고 등록: 완전 무료 · 사업자번호당 동시 노출 최대 10개\n'
            '※ 가입 보너스: 일자리 알림핀 ${PushPackageCatalog.signupBonusPushes}회 · '
            '검증 보너스 ${PushPackageCatalog.verificationBonusPushes}회\n'
            '※ 노출(알림핀·정류장 표시핀): ${PushPackageCatalog.krwSuffix(PushPackageCatalog.exposureUnitPriceKrw)}/회 · '
            '10회 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.pack10Price(PushPackageCatalog.exposureUnitPriceKrw))}\n'
            '※ 노출+PUSH: ${PushPackageCatalog.krwSuffix(PushPackageCatalog.exposureWithPushUnitPriceKrw)}/회 · '
            '10회 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.pack10Price(PushPackageCatalog.exposureWithPushUnitPriceKrw))}\n'
            '※ PUSH 알림권: ${PushPackageCatalog.krwSuffix(PushPackageCatalog.pushOnlyUnitPriceKrw)}/회 · '
            '노출 ${PushPackageCatalog.exposureEndsLabel}',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          if (ProductFeatureFlags.isHiringCommissionEnabled) ...[
            const SizedBox(height: 8),
            Text(
              PremiumPartnershipPlans.commissionSavingsNote,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
