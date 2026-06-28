import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 지도에서 좌표만 선택 — 이름·시간 입력 없음
Future<GeoCoordinate?> showShuttleStopCoordinatePicker(
  BuildContext context, {
  required GeoCoordinate initial,
  List<CommuteRouteStop> existingStops = const [],
}) {
  return showAdaptiveSheet<GeoCoordinate>(
    context: context,
    builder: (ctx) => _ShuttleStopCoordinatePickerSheet(
      initial: initial,
      existingStops: existingStops,
    ),
  );
}

class _ShuttleStopCoordinatePickerSheet extends StatefulWidget {
  const _ShuttleStopCoordinatePickerSheet({
    required this.initial,
    required this.existingStops,
  });

  final GeoCoordinate initial;
  final List<CommuteRouteStop> existingStops;

  @override
  State<_ShuttleStopCoordinatePickerSheet> createState() =>
      _ShuttleStopCoordinatePickerSheetState();
}

class _ShuttleStopCoordinatePickerSheetState
    extends State<_ShuttleStopCoordinatePickerSheet> {
  late GeoCoordinate _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initial;
  }

  List<PushRadiusMapOverlayPoint> get _overlays {
    return widget.existingStops.asMap().entries.map((entry) {
      final stop = entry.value;
      return PushRadiusMapOverlayPoint(
        coordinate: stop.coordinate,
        radiusMeters: 0,
        label: stop.label,
        pointIndex: entry.key,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              '지도를 드래그해 핀 위치를 맞추세요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PushRadiusMapPicker(
                  center: _center,
                  radiusMeters: 0,
                  hideZeroRadiusLabel: true,
                  existingPoints: _overlays,
                  activePointLabel: '새 정류장',
                  onCenterChanged: (coord) => setState(() => _center = coord),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_center.latitude.toStringAsFixed(5)}, '
                  '${_center.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_center),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '이 위치 사용',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// @deprecated — 정류장 등록은 노선 편집 화면 바텀시트 사용
class ShuttleStopPickResult {
  const ShuttleStopPickResult({
    required this.label,
    required this.coordinate,
    this.departureTime,
    this.photoPath,
  });

  final String label;
  final GeoCoordinate coordinate;
  final String? departureTime;
  final String? photoPath;
}

/// @deprecated — [showShuttleStopCoordinatePicker] 사용
class ShuttleStopMapPickerPage extends StatefulWidget {
  const ShuttleStopMapPickerPage({
    super.key,
    this.existingStops = const [],
  });

  final List<CommuteRouteStop> existingStops;

  @override
  State<ShuttleStopMapPickerPage> createState() =>
      _ShuttleStopMapPickerPageState();
}

class _ShuttleStopMapPickerPageState extends State<ShuttleStopMapPickerPage> {
  late GeoCoordinate _center;

  @override
  void initState() {
    super.initState();
    _center = widget.existingStops.isNotEmpty
        ? widget.existingStops.last.coordinate
        : GeoCoordinate(
            latitude: MapConstants.warehouseAreaCenter.latitude,
            longitude: MapConstants.warehouseAreaCenter.longitude,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PushRadiusMapPicker(
                center: _center,
                radiusMeters: 0,
                hideZeroRadiusLabel: true,
                onCenterChanged: (c) => setState(() => _center = c),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  ShuttleStopPickResult(label: '', coordinate: _center),
                ),
                child: const Text('이 위치 사용'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
