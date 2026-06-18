import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/presentation/widgets/urgent_hire_brand.dart';

/// 공고 탭 하단 — 통근버스·알림핀·급구알림 안내 (금액 없음, 탭 후 상세)
class CorporatePostServicesGuide extends StatelessWidget {
  const CorporatePostServicesGuide({super.key});

  Future<void> _openShuttle(BuildContext context) async {
    await Navigator.of(context).pushNamed(AppRoutes.corporateShuttleRoutes);
  }

  Future<void> _openPinShop(BuildContext context) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.corporatePushPackageShop,
      arguments: PushPackageCatalog.exposureSingleId,
    );
  }

  Future<void> _openPushShop(BuildContext context) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.corporatePushPackageShop,
      arguments: PushPackageCatalog.pushSingleId,
    );
  }

  void _showPushGuide(BuildContext context) {
    _openPushShop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '노출·알림 서비스',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '서비스를 선택하면 이용 방법과 요금 안내 화면으로 이동합니다.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _GuideTile(
                icon: Icons.directions_bus_filled_outlined,
                iconColor: AppColors.primary,
                title: '통근버스',
                subtitle: '노선·정류장 등록',
                onTap: () => _openShuttle(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GuideTile(
                icon: Icons.push_pin_outlined,
                iconColor: AppColors.primary,
                title: '알림핀',
                subtitle: '지도 거점 노출',
                onTap: () => _openPinShop(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GuideTile(
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFF7B1FA2),
                title: '급구알림',
                subtitle: '구직자 PUSH',
                onTap: () => _showPushGuide(context),
                trailing: const UrgentHireBadge(height: 14, fontSize: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
