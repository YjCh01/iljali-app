import 'dart:io';

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 노선 정류장 미리보기 — 등록 화면용 미니 지도
class ShuttleRouteStopsPreview extends StatelessWidget {
  const ShuttleRouteStopsPreview({
    super.key,
    required this.stops,
    required this.colorHex,
  });

  final List<CommuteRouteStop> stops;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();

    final center = stops.last.coordinate;
    final routeColor = ShuttleRouteColorUtils.parseHex(colorHex);
    final overlayPoints = stops.asMap().entries.map((entry) {
      return PushRadiusMapOverlayPoint(
        coordinate: entry.value.coordinate,
        radiusMeters: 0,
        label: entry.value.label,
        pointIndex: entry.key,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.route, size: 18, color: routeColor),
            const SizedBox(width: 6),
            Text(
              '노선 미리보기 · ${stops.length}개 정류장',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 168,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: PushRadiusMapPicker(
              center: center,
              radiusMeters: 0,
              hideZeroRadiusLabel: true,
              existingPoints: overlayPoints,
              centerEditable: false,
              mapZoom: _zoomForStops(stops),
              onCenterChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  double _zoomForStops(List<CommuteRouteStop> stops) {
    if (stops.length < 2) return 14;
    var maxSpan = 0.0;
    for (var i = 0; i < stops.length; i++) {
      for (var j = i + 1; j < stops.length; j++) {
        final a = stops[i].coordinate;
        final b = stops[j].coordinate;
        final span = (a.latitude - b.latitude).abs() +
            (a.longitude - b.longitude).abs();
        if (span > maxSpan) maxSpan = span;
      }
    }
    if (maxSpan > 0.15) return 11;
    if (maxSpan > 0.05) return 12;
    if (maxSpan > 0.02) return 13;
    return 14;
  }
}

/// 정류장 목록 타일 — 드래그·수정용
class ShuttleRouteStopTile extends StatelessWidget {
  const ShuttleRouteStopTile({
    super.key,
    required this.index,
    required this.stop,
    required this.routeColorHex,
    required this.onEdit,
    required this.onDelete,
    required this.dragHandle,
  });

  final int index;
  final CommuteRouteStop stop;
  final String routeColorHex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final routeColor = ShuttleRouteColorUtils.parseHex(routeColorHex);
    final hasPhoto =
        stop.photoPath != null && File(stop.photoPath!).existsSync();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              dragHandle,
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: routeColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: routeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: routeColor.computeLuminance() > 0.55
                        ? AppColors.textPrimary
                        : routeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (hasPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(stop.photoPath!),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.searchBarBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.place_outlined,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.departureTime == null
                          ? (index == 0 ? '출발지' : '도착 또는 경유')
                          : '탑승 ${stop.departureTime}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
