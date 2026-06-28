import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/legal/business_disclosure.dart';
import 'package:map/core/utils/external_link_launcher.dart';

/// 전자상거래법 사업자 신원 표시 + 공정위 사업자정보 조회 링크
class BusinessDisclosureFooter extends StatelessWidget {
  const BusinessDisclosureFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사업자 정보',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          for (final line in BusinessDisclosure.footerLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openFtc(context),
            child: Text(
              '공정거래위원회 사업자정보 확인',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.95),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFtc(BuildContext context) async {
    final opened = await openExternalUrl(BusinessDisclosure.ftcVerificationUrl);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? '공정위 사업자정보 페이지를 열었습니다.'
              : '공정위 조회 링크를 복사했습니다. 브라우저에 붙여넣어 주세요.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
