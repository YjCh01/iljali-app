import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_cluster_engine.dart';

/// 기업 홈 — 주변 채용 mock 지도 (드래그 이동 · 핀만 표시)
class CorporateExposureMiniMap extends StatefulWidget {
  const CorporateExposureMiniMap({
    super.key,
    required this.pins,
    required this.ownPostIds,
    this.interactive = false,
    this.onPinTap,
    this.initialZoom = 12.0,
  });

  final List<JobMapPin> pins;
  final Set<String> ownPostIds;
  final bool interactive;
  final ValueChanged<JobMapPin>? onPinTap;
  final double initialZoom;

  @override
  State<CorporateExposureMiniMap> createState() =>
      _CorporateExposureMiniMapState();
}

class _CorporateExposureMiniMapState extends State<CorporateExposureMiniMap> {
  late final double _zoom;
  Offset _panOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
  }

  @override
  void didUpdateWidget(CorporateExposureMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactive && oldWidget.interactive) {
      _panOffset = Offset.zero;
    }
  }

  JobMapPinDisplayTier _tierForCluster(JobMapCluster cluster) {
    var tier = JobMapPinDisplayTier.standard;
    for (final pin in cluster.pins) {
      tier = JobMapPinDisplayTierX.maxOf(tier, pin.displayTier);
    }
    return tier;
  }

  bool _clusterHasOwn(JobMapCluster cluster) =>
      cluster.pins.any((p) => widget.ownPostIds.contains(p.post.id));

  Offset _toOffset(double lat, double lng, Size mapSize) {
    final center = MapConstants.warehouseAreaCenter;
    final scale = 4200 * math.pow(2, _zoom - 12);
    final dx =
        (lng - center.longitude) * scale + mapSize.width / 2 + _panOffset.dx;
    final dy =
        (center.latitude - lat) * scale + mapSize.height / 2 + _panOffset.dy;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final clusters = JobMapClusterEngine.cluster(pins: widget.pins, zoom: _zoom);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onPanUpdate: widget.interactive
                  ? (details) {
                      setState(() => _panOffset += details.delta);
                    }
                  : null,
              child: CustomPaint(
                painter: _GridPainter(),
                size: mapSize,
              ),
            ),
            ...clusters.map((cluster) {
              final offset = _toOffset(
                cluster.latitude,
                cluster.longitude,
                mapSize,
              );
              final tier = _tierForCluster(cluster);
              final isOwn = _clusterHasOwn(cluster);
              final size = tier.markerSize * (widget.interactive ? 0.88 : 0.72);
              return Positioned(
                left: offset.dx - size / 2,
                top: offset.dy - size / 2,
                child: GestureDetector(
                  onTap: widget.onPinTap == null || !cluster.isSingle
                      ? null
                      : () => widget.onPinTap!(cluster.singlePin),
                  child: _PinDot(
                    tier: tier,
                    label: cluster.count > 1 ? '${cluster.count}' : tier.shapeGlyph,
                    size: size,
                    isOwn: isOwn,
                  ),
                ),
              );
            }),
            if (widget.pins.isEmpty)
              Center(
                child: Text(
                  '표시할 공고가 없습니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({
    required this.tier,
    required this.label,
    required this.size,
    this.isOwn = false,
  });

  final JobMapPinDisplayTier tier;
  final String label;
  final double size;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tier.pinColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isOwn ? AppColors.primary : tier.pinBorderColor,
          width: isOwn ? 2.5 : tier.borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: tier.pinColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          if (isOwn)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
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
      ..color = AppColors.primaryLight.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    const step = 40.0;
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
