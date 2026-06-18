import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_service_action_style.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 셔틀 노선 지도 오버레이 유료 활성화 UI
class ShuttleOverlayActivationSection extends StatelessWidget {
  const ShuttleOverlayActivationSection({
    super.key,
    required this.post,
    this.busy = false,
    this.onActivate,
    this.onOpenShop,
    this.compact = false,
  });

  final CorporateJobPost post;
  final bool busy;
  final VoidCallback? onActivate;
  final VoidCallback? onOpenShop;
  final bool compact;

  bool get _hasRoute {
    final routeId = post.commuteRouteId?.trim();
    return routeId != null && routeId.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRoute) {
      return _HintBox(
        compact: compact,
        icon: Icons.info_outline_rounded,
        message: '노선을 먼저 연결하세요',
        color: AppColors.textSecondary,
      );
    }

    if (post.hasShuttleRouteOverlay) {
      return _HintBox(
        compact: compact,
        icon: Icons.check_circle_rounded,
        message: '구직자 지도에 노선·정류장 노출 중',
        color: const Color(0xFF2E7D32),
        background: const Color(0xFFE8F5E9),
        border: const Color(0xFFA5D6A7),
      );
    }

    return _ActivationCard(
      compact: compact,
      busy: busy,
      onActivate: onActivate,
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({
    required this.compact,
    required this.icon,
    required this.message,
    required this.color,
    this.background,
    this.border,
  });

  final bool compact;
  final IconData icon;
  final String message;
  final Color color;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(
          color: border ?? AppColors.searchBarBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 16 : 20, color: color),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({
    required this.compact,
    required this.busy,
    this.onActivate,
  });

  final bool compact;
  final bool busy;
  final VoidCallback? onActivate;

  static const _setupBg = CorporateServiceActionStyle.setupBackground;
  static const _setupBorder = CorporateServiceActionStyle.setupBorder;
  static const _setupAccent = CorporateServiceActionStyle.setupForeground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: _setupBg,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: _setupBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.map_outlined,
                size: compact ? 18 : 20,
                color: _setupAccent,
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: Text(
                  compact
                      ? '노선·정류장 지도 노출은 별도 활성화(알림핀 1회)입니다.'
                      : '노선 연결만으로는 구직자 지도에 표시되지 않습니다.\n'
                          '지도에 노선·정류장을 노출하려면 별도 활성화가 필요합니다.',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          FilledButton.icon(
            onPressed: busy ? null : onActivate,
            icon: busy
                ? SizedBox(
                    width: compact ? 14 : 16,
                    height: compact ? 14 : 16,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.directions_bus_filled, size: compact ? 16 : 18),
            label: Text(
              compact
                  ? '지도 노선 활성화 (알림핀 1회)'
                  : '지도 노선·정류장 활성화 (일자리 알림핀 1회)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12 : 14,
              ),
            ),
            style: CorporateServiceActionStyle.setupFilled().copyWith(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: compact ? 10 : 14),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
