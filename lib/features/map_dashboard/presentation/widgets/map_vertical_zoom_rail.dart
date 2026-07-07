import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 웹 NAVER 지도용 세로 줌 레일 — + / 슬라이더 / − (축척 텍스트 없음)
class MapVerticalZoomRail extends StatelessWidget {
  const MapVerticalZoomRail({
    super.key,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  static const zoomStep = 1.0;

  void _stepUp() =>
      onZoomChanged((zoom + zoomStep).clamp(minZoom, maxZoom));

  void _stepDown() =>
      onZoomChanged((zoom - zoomStep).clamp(minZoom, maxZoom));

  @override
  Widget build(BuildContext context) {
    final divisions = (maxZoom - minZoom).round();

    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      color: AppColors.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: zoom < maxZoom ? _stepUp : null,
              icon: Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              tooltip: '확대',
            ),
            SizedBox(
              height: 108,
              width: 40,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    showValueIndicator: ShowValueIndicator.never,
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: zoom.clamp(minZoom, maxZoom),
                    min: minZoom,
                    max: maxZoom,
                    divisions: divisions > 0 ? divisions : 1,
                    onChanged: onZoomChanged,
                  ),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: zoom > minZoom ? _stepDown : null,
              icon: Icon(
                Icons.remove_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              tooltip: '축소',
            ),
          ],
        ),
      ),
    );
  }
}
