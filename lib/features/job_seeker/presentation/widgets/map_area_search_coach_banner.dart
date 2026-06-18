import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/onboarding/user_onboarding_flags.dart';

/// 지도 영역 검색 코치마크 — 최초 1회 표시, 닫기 시 재표시 안 함
class MapAreaSearchCoachBanner extends StatefulWidget {
  const MapAreaSearchCoachBanner({super.key});

  @override
  State<MapAreaSearchCoachBanner> createState() =>
      _MapAreaSearchCoachBannerState();
}

class _MapAreaSearchCoachBannerState extends State<MapAreaSearchCoachBanner> {
  bool _visible = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dismissed =
        await UserOnboardingFlags.isMapAreaSearchCoachDismissed();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _visible = !dismissed;
    });
  }

  Future<void> _dismiss() async {
    await UserOnboardingFlags.dismissMapAreaSearchCoach();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_visible) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Icon(
              Icons.swipe_rounded,
              size: 20,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '지도를 움직인 뒤 이 지역 검색하기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
