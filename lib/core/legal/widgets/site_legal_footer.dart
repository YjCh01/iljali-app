import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/legal/business_disclosure.dart';
import 'package:map/core/utils/external_link_launcher.dart';

/// 사이트 공통 푸터 — 전자상거래법 사업자 표시 + 요금·약관 링크
class SiteLegalFooter extends StatelessWidget {
  const SiteLegalFooter({
    super.key,
    this.variant = SiteLegalFooterVariant.light,
    this.compact = false,
  });

  final SiteLegalFooterVariant variant;
  final bool compact;

  bool get _dark => variant == SiteLegalFooterVariant.dark;

  @override
  Widget build(BuildContext context) {
    final muted = _dark ? Colors.white70 : AppColors.textSecondary.withValues(alpha: 0.88);
    final link = _dark ? Colors.white : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _FooterLink(
                label: '요금 안내',
                color: link,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.publicPricing),
              ),
              Text('·', style: TextStyle(color: muted, fontSize: 11)),
              _FooterLink(
                label: '이용약관',
                color: link,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.legalDocuments),
              ),
              Text('·', style: TextStyle(color: muted, fontSize: 11)),
              _FooterLink(
                label: '환불정책',
                color: link,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.legalDocuments,
                  arguments: {'initialDocumentId': 'paid_refund'},
                ),
              ),
              Text('·', style: TextStyle(color: muted, fontSize: 11)),
              _FooterLink(
                label: '고객센터',
                color: link,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.customerSupport),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Text(
          '상호: ${BusinessDisclosure.businessName} · 대표: ${BusinessDisclosure.representative}',
          style: TextStyle(fontSize: 11, height: 1.45, color: muted),
        ),
        Text(
          '사업자등록번호: ${BusinessDisclosure.registrationNumber}',
          style: TextStyle(fontSize: 11, height: 1.45, color: muted),
        ),
        Text(
          '주소: ${BusinessDisclosure.address}',
          style: TextStyle(fontSize: 11, height: 1.45, color: muted),
        ),
        Text(
          '연락처: ${BusinessDisclosure.phone} · ${BusinessDisclosure.email}',
          style: TextStyle(fontSize: 11, height: 1.45, color: muted),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () => openExternalUrl(BusinessDisclosure.ftcVerificationUrl),
            child: Text(
              '공정거래위원회 사업자정보 확인',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: link,
                decoration: TextDecoration.underline,
                decorationColor: link,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum SiteLegalFooterVariant { light, dark }

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}
