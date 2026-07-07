import 'package:flutter/material.dart';
import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:map/core/constants/app_colors.dart';

/// 구인자 화면 상단 — 토스 PG 전 무료 노출 안내
class FreeExposureLaunchBanner extends StatefulWidget {
  const FreeExposureLaunchBanner({super.key});

  @override
  State<FreeExposureLaunchBanner> createState() =>
      _FreeExposureLaunchBannerState();
}

class _FreeExposureLaunchBannerState extends State<FreeExposureLaunchBanner> {
  bool? _active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await FreeExposureLaunchPolicy.isActive();
    if (!mounted) return;
    setState(() => _active = active);
  }

  @override
  Widget build(BuildContext context) {
    if (_active != true) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFFE8F4FD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 20,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FreeExposureLaunchPolicy.bannerTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FreeExposureLaunchPolicy.bannerBody,
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
      ),
    );
  }
}
