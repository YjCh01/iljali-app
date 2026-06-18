import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// mock/MVP 지도용 줌 조절 바 — 구인자 반경 슬라이더와 동일한 − / + 패턴
class MapZoomControlBar extends StatelessWidget {
  const MapZoomControlBar({
    super.key,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
    this.caption,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;
  final String? caption;

  static const zoomStep = 0.8;

  void _stepDown() =>
      onZoomChanged((zoom - zoomStep).clamp(minZoom, maxZoom));

  void _stepUp() => onZoomChanged((zoom + zoomStep).clamp(minZoom, maxZoom));

  @override
  Widget build(BuildContext context) {
    final divisions = ((maxZoom - minZoom) / zoomStep).round();

    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: AppColors.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: zoom > minZoom ? _stepDown : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                    child: Slider(
                      value: zoom,
                      min: minZoom,
                      max: maxZoom,
                      divisions: divisions > 0 ? divisions : 1,
                      onChanged: onZoomChanged,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: zoom < maxZoom ? _stepUp : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
