import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 지도 이동 후 수동으로 해당 영역 공고를 다시 불러올 때 사용
class MapSearchAreaButton extends StatelessWidget {
  const MapSearchAreaButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      color: AppColors.surface,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                )
              else
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.primary.withValues(alpha: 0.95),
                ),
              const SizedBox(width: 8),
              Text(
                loading ? '불러오는 중…' : '이 지역 검색하기',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
