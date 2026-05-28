import 'package:flutter/material.dart';
import 'package:map/core/widgets/mvp_feedback.dart';
import 'package:map/core/constants/app_colors.dart';

/// 기업회원 탭 공통 — 둥근 카드 컨테이너
class CorporateSurfaceCard extends StatelessWidget {
  const CorporateSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.searchBarBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }
}

void showCorporateComingSoonSnackBar(BuildContext context, String label) {
  showMvpInfoSnackBar(context, label);
}
