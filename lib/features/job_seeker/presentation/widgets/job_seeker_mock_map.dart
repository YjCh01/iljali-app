import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/utils/commute_route_polyline.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_cluster_engine.dart';
import 'package:map/features/job_seeker/domain/utils/mock_map_viewport.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_area_button.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_zoom_control_bar.dart';

/// Naver Map 미사용 환경용 — 줌·클러스터 mock 지도
class JobSeekerMockMap extends StatefulWidget {
  const JobSeekerMockMap({
    super.key,
    required this.pins,
    this.shuttleRoute,
    this.shuttleWorkplace,
    required this.onPinTap,
    this.onClusterTap,
    this.onViewportChanged,
    this.areaSearchPending = false,
    this.areaSearchLoading = false,
    this.onSearchArea,
  });

  final List<JobMapPin> pins;
  final CommuteRoute? shuttleRoute;
  final GeoCoordinate? shuttleWorkplace;
  final ValueChanged<JobMapPin> onPinTap;
  final ValueChanged<JobMapCluster>? onClusterTap;
  final VoidCallback? onViewportChanged;
  final bool areaSearchPending;
  final bool areaSearchLoading;
  final VoidCallback? onSearchArea;

  @override
  State<JobSeekerMockMap> createState() => JobSeekerMockMapState();
}

class JobSeekerMockMapState extends State<JobSeekerMockMap> {
  double _zoom = 12.5;
  Offset _panOffset = Offset.zero;
  static const _minZoom = 10.0;
  static const _maxZoom = 16.0;

  void _notifyViewportChanged() => widget.onViewportChanged?.call();

  MapViewportBounds get currentViewport {
    final size = _lastMapSize ?? const Size(360, 640);
    return MockMapViewport.resolve(
      mapSize: size,
      panOffset: _panOffset,
      zoom: _zoom,
    );
  }

  Size? _lastMapSize;

  void _setZoom(double value) {
    setState(() => _zoom = value.clamp(_minZoom, _maxZoom));
  }

  @override
  Widget build(BuildContext context) {
    final clusters = JobMapClusterEngine.cluster(
      pins: widget.pins,
      zoom: _zoom,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        _lastMapSize = mapSize;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _panOffset += details.delta;
                  });
                },
                onPanEnd: (_) => _notifyViewportChanged(),
                child: CustomPaint(
                  painter: _GridPainter(
                    shuttleRoute: widget.shuttleRoute,
                    shuttleWorkplace: widget.shuttleWorkplace,
                    panOffset: _panOffset,
                    mapSize: mapSize,
                  ),
                ),
              ),
            ),
            ...clusters.map((cluster) {
              final offset = _toOffset(
                cluster.latitude,
                cluster.longitude,
                mapSize,
              ) +
                  _panOffset;
              return Positioned(
                left: offset.dx - 26,
                top: offset.dy - 26,
                child: GestureDetector(
                  onTap: () {
                    if (cluster.isSingle) {
                      widget.onPinTap(cluster.singlePin);
                    } else {
                      widget.onClusterTap?.call(cluster);
                    }
                  },
                  child: _ClusterBubble(
                    count: cluster.count,
                    tier: cluster.isSingle
                        ? cluster.singlePin.displayTier
                        : cluster.displayTier,
                  ),
                ),
              );
            }),
            if (widget.pins.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 48,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '표시할 공고가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '검색 조건을 바꾸거나\n다른 지역을 확인해 보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.areaSearchPending) ...[
                    MapSearchAreaButton(
                      loading: widget.areaSearchLoading,
                      onPressed: widget.onSearchArea,
                    ),
                    const SizedBox(height: 16),
                  ],
                  MapZoomControlBar(
                    zoom: _zoom,
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                    onZoomChanged: _setZoom,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _toOffset(double lat, double lng, Size mapSize) {
    final center = MapConstants.warehouseAreaCenter;
    final dx = (lng - center.longitude) * 4200 + mapSize.width / 2;
    final dy = (center.latitude - lat) * 4200 + mapSize.height / 2;
    return Offset(dx, dy);
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.tier});

  final int count;
  final JobMapPinDisplayTier tier;

  @override
  Widget build(BuildContext context) {
    final baseSize = tier.markerSize;
    final size = count > 1 ? baseSize + 8 : baseSize;
    final label = count > 1 ? '$count' : tier.shapeGlyph;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: count > 1 ? tier.pinLightColor : tier.pinColor,
        border: Border.all(color: tier.pinBorderColor, width: tier.borderWidth),
        boxShadow: [
          BoxShadow(
            color: tier.pinColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: count > 1 ? 15 : size * 0.38,
          height: 1,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    this.shuttleRoute,
    this.shuttleWorkplace,
    this.panOffset = Offset.zero,
    this.mapSize = Size.zero,
  });

  final CommuteRoute? shuttleRoute;
  final GeoCoordinate? shuttleWorkplace;
  final Offset panOffset;
  final Size mapSize;

  Offset _toOffset(double lat, double lng, Size size) {
    final center = MapConstants.warehouseAreaCenter;
    final dx = (lng - center.longitude) * 4200 + size.width / 2;
    final dy = (center.latitude - lat) * 4200 + size.height / 2;
    return Offset(dx, dy) + panOffset;
  }

  Color _parseHex(String hex) {
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFFE53935);
    return Color(parsed);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final route = shuttleRoute;
    if (route == null) return;
    final points = CommuteRoutePolyline.pathIncludingWorkplace(
      route: route,
      workplace: shuttleWorkplace,
    );
    if (points.length < 2) return;

    final effectiveSize = mapSize == Size.zero ? size : mapSize;
    final offsets = points
        .map((c) => _toOffset(c.latitude, c.longitude, effectiveSize))
        .toList();

    final lineColor = _parseHex(route.overlayColorHex);
    final outline = lineColor.computeLuminance() > 0.65
        ? Colors.black54
        : Colors.white;

    _drawDashedPath(
      canvas,
      offsets,
      paint: Paint()
        ..color = outline
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      solid: true,
    );
    _drawDashedPath(
      canvas,
      offsets,
      paint: Paint()
        ..color = lineColor
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      dashLength: 14,
      gapLength: 8,
    );

    final dotPaint = Paint()..color = lineColor;
    final dotOutline = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final stop in route.stops) {
      final offset = _toOffset(
        stop.coordinate.latitude,
        stop.coordinate.longitude,
        effectiveSize,
      );
      canvas.drawCircle(offset, 6, dotPaint);
      canvas.drawCircle(offset, 6, dotOutline);
    }

    if (shuttleWorkplace != null) {
      final workplaceOffset = _toOffset(
        shuttleWorkplace!.latitude,
        shuttleWorkplace!.longitude,
        effectiveSize,
      );
      final workplacePaint = Paint()..color = const Color(0xFF5E35B1);
      canvas.drawCircle(workplaceOffset, 7, workplacePaint);
      canvas.drawCircle(workplaceOffset, 7, dotOutline);
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    List<Offset> points, {
    required Paint paint,
    double dashLength = 14,
    double gapLength = 8,
    bool solid = false,
  }) {
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final path = Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);
      if (solid) {
        canvas.drawPath(path, paint);
        continue;
      }
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final next = distance + dashLength;
          final extract = metric.extractPath(
            distance,
            next.clamp(0, metric.length),
          );
          canvas.drawPath(extract, paint);
          distance = next + gapLength;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.shuttleRoute != shuttleRoute ||
      oldDelegate.shuttleWorkplace != shuttleWorkplace ||
      oldDelegate.panOffset != panOffset ||
      oldDelegate.mapSize != mapSize;
}
