import 'package:flutter/material.dart';
import 'package:map/core/branding/iljari_ad_campaign.dart';
import 'package:map/core/branding/iljari_icon_painter.dart';
import 'package:map/core/constants/app_colors.dart';

/// 앱·웹 초기 로딩 — 브랜드 아이콘 + 광고 카피
class IljariAppLoadingView extends StatelessWidget {
  const IljariAppLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.authBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IljariAppIcon(
                size: 88,
                borderRadius: BorderRadius.circular(22),
              ),
              const SizedBox(height: 28),
              const IljariAdCampaignCopy(),
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
