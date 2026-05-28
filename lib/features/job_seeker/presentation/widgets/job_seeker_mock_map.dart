import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_cluster_engine.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_zoom_control_bar.dart';

/// Naver Map 미사용 환경용 — 줌·클러스터 mock 지도
class JobSeekerMockMap extends StatefulWidget {
  const JobSeekerMockMap({
    super.key,
    required this.pins,
    required this.onPinTap,
  });

  final List<JobMapPin> pins;
  final ValueChanged<JobMapPin> onPinTap;

  @override
  State<JobSeekerMockMap> createState() => _JobSeekerMockMapState();
}

class _JobSeekerMockMapState extends State<JobSeekerMockMap> {
  double _zoom = 12.5;
  static const _minZoom = 10.0;
  static const _maxZoom = 16.0;

  void _setZoom(double value) =>
      setState(() => _zoom = value.clamp(_minZoom, _maxZoom));

  void _zoomIn() => _setZoom(_zoom + MapZoomControlBar.zoomStep);

  @override
  Widget build(BuildContext context) {
    final clusters = JobMapClusterEngine.cluster(
      pins: widget.pins,
      zoom: _zoom,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
            ...clusters.map((cluster) {
              final offset = _toOffset(
                cluster.latitude,
                cluster.longitude,
                mapSize,
              );
              return Positioned(
                left: offset.dx - 26,
                top: offset.dy - 26,
                child: GestureDetector(
                  onTap: () {
                    if (cluster.isSingle) {
                      widget.onPinTap(cluster.singlePin);
                    } else {
                      _zoomIn();
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
              bottom: 16,
              child: MapZoomControlBar(
                zoom: _zoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onZoomChanged: _setZoom,
                caption:
                    'mock · 줌 ${_zoom.toStringAsFixed(1)} · 공고 ${widget.pins.length}',
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
