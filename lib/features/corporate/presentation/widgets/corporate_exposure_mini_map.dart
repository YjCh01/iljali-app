import 'dart:math' as math;



import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/constants/map_constants.dart';

import 'package:map/core/geo/device_location_service.dart';

import 'package:map/features/corporate/domain/entities/corporate_shuttle_map_overlay.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_shuttle_density_painter.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

import 'package:map/features/job_seeker/domain/utils/job_map_cluster_engine.dart';
import 'package:map/features/job_seeker/domain/utils/mock_map_viewport.dart';

import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';



/// 기업 홈 — 격자 mock 지도 + 채용 핀 (네이버 타일 아님 · 구직자 지도 탭에서 실지도)

class CorporateExposureMiniMap extends StatefulWidget {

  const CorporateExposureMiniMap({

    super.key,

    required this.pins,

    required this.ownPostIds,

    this.shuttleOverlays = const [],

    this.interactive = false,

    this.onPinTap,

    this.onShuttleStopTap,

    this.initialZoom = MapConstants.defaultZoom,

    this.selectedPostId,

    this.centerOnPin,

  });



  final List<JobMapPin> pins;

  final Set<String> ownPostIds;

  final List<CorporateShuttleMapOverlay> shuttleOverlays;

  final bool interactive;

  final ValueChanged<JobMapPin>? onPinTap;

  final ValueChanged<CorporateShuttleMapOverlay>? onShuttleStopTap;

  final double initialZoom;

  final String? selectedPostId;

  final JobMapPin? centerOnPin;



  @override

  State<CorporateExposureMiniMap> createState() =>

      _CorporateExposureMiniMapState();

}



class _CorporateExposureMiniMapState extends State<CorporateExposureMiniMap> {

  late double _zoom;

  Offset _panOffset = Offset.zero;

  JobMapPin? _pendingCenterPin;



  @override

  void initState() {

    super.initState();

    _zoom = widget.initialZoom;

    _restoreViewportFromSession();

    if (widget.centerOnPin != null) {

      _pendingCenterPin = widget.centerOnPin;

    }

  }



  void _restoreViewportFromSession() {

    if (!widget.interactive) return;

    final saved = MapViewportSessionStore.instance

        .peek(MapViewportSessionKeys.corporateHome);

    if (saved == null) return;

    _zoom = saved.zoom;

    _panOffset = MockMapViewport.panOffsetToCenterOn(

      target: saved.center,

      zoom: _zoom,

    );

  }



  void _persistViewport(Size mapSize) {

    if (!widget.interactive) return;

    final bounds = MockMapViewport.resolve(

      mapSize: mapSize,

      panOffset: _panOffset,

      zoom: _zoom,

    );

    final centerLat = (bounds.north + bounds.south) / 2;

    final centerLng = (bounds.east + bounds.west) / 2;

    MapViewportSessionStore.instance.remember(

      MapViewportSessionKeys.corporateHome,

      MapViewportSnapshot(

        latitude: centerLat,

        longitude: centerLng,

        zoom: _zoom,

      ),

    );

  }



  @override

  void didUpdateWidget(CorporateExposureMiniMap oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (!widget.interactive && oldWidget.interactive) {

      _panOffset = Offset.zero;

    }

    if (widget.centerOnPin != null &&

        widget.centerOnPin != oldWidget.centerOnPin) {

      _pendingCenterPin = widget.centerOnPin;

    }

  }



  void _centerOnPin(JobMapPin pin, Size mapSize) {

    final center = MapConstants.warehouseAreaCenter;

    final scale = 4200 * math.pow(2, _zoom - 12);

    setState(() {

      _panOffset = Offset(

        -(pin.longitude - center.longitude) * scale,

        (pin.latitude - center.latitude) * scale,

      );

    });

    _persistViewport(mapSize);

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



  Future<bool> _focusMockOnUserLocation() async {

    final position = await DeviceLocationService.getCurrentPosition();

    if (position == null) return false;

    final scale = 4200 * math.pow(2, _zoom - 12);

    setState(() {

      _panOffset = Offset(

        -(position.longitude -

                MapConstants.warehouseAreaCenter.longitude) *

            scale,

        (position.latitude - MapConstants.warehouseAreaCenter.latitude) *

            scale,

      );

    });

    return true;

  }



  Offset _toOffset(double lat, double lng, Size mapSize) {

    final center = MapConstants.warehouseAreaCenter;

    final scale = 4200 * math.pow(2, _zoom - 12);

    final dx =

        (lng - center.longitude) * scale + mapSize.width / 2 + _panOffset.dx;

    final dy =

        (center.latitude - lat) * scale + mapSize.height / 2 + _panOffset.dy;

    return Offset(dx, dy);

  }



  List<Widget> _shuttleStopHitTargets(Size mapSize) {

    if (!widget.interactive || widget.onShuttleStopTap == null) {

      return const [];

    }



    const hitSize = 28.0;

    final widgets = <Widget>[];

    for (final overlay in widget.shuttleOverlays) {

      for (final stop in overlay.route.stops) {

        final offset = _toOffset(

          stop.coordinate.latitude,

          stop.coordinate.longitude,

          mapSize,

        );

        widgets.add(

          Positioned(

            left: offset.dx - hitSize / 2,

            top: offset.dy - hitSize / 2,

            width: hitSize,

            height: hitSize,

            child: GestureDetector(

              behavior: HitTestBehavior.translucent,

              onTap: () => widget.onShuttleStopTap!(overlay),

            ),

          ),

        );

      }

    }

    return widgets;

  }



  @override

  Widget build(BuildContext context) {

    final clusters = JobMapClusterEngine.cluster(pins: widget.pins, zoom: _zoom);



    return LayoutBuilder(

      builder: (context, constraints) {

        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_pendingCenterPin != null) {

          final pin = _pendingCenterPin!;

          _pendingCenterPin = null;

          WidgetsBinding.instance.addPostFrameCallback((_) {

            if (mounted) _centerOnPin(pin, mapSize);

          });

        }



        return Stack(

          fit: StackFit.expand,

          children: [

            GestureDetector(

              onPanUpdate: widget.interactive

                  ? (details) {

                      setState(() => _panOffset += details.delta);

                    }

                  : null,

              onPanEnd: widget.interactive

                  ? (_) => _persistViewport(mapSize)

                  : null,

              child: CustomPaint(

                painter: CorporateShuttleDensityPainter(

                  overlays: widget.shuttleOverlays,

                  panOffset: _panOffset,

                  zoom: _zoom,

                  mapSize: mapSize,

                ),

                foregroundPainter: _GridPainter(),

                size: mapSize,

              ),

            ),

            ..._shuttleStopHitTargets(mapSize),

            ...clusters.map((cluster) {

              final offset = _toOffset(

                cluster.latitude,

                cluster.longitude,

                mapSize,

              );

              final tier = _tierForCluster(cluster);

              final isOwn = _clusterHasOwn(cluster);

              final isSelected = cluster.isSingle &&

                  cluster.singlePin.post.id == widget.selectedPostId;

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

                    isSelected: isSelected,

                  ),

                ),

              );

            }),

            if (widget.pins.isEmpty && widget.shuttleOverlays.isEmpty)

              Center(

                child: Text(

                  '표시할 공고가 없습니다',

                  style: TextStyle(

                    fontSize: 13,

                    color: AppColors.textSecondary.withValues(alpha: 0.9),

                  ),

                ),

              ),

            if (widget.interactive)

              MapCurrentLocationButton(

                onMockLocate: _focusMockOnUserLocation,

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

    this.isSelected = false,

  });



  final JobMapPinDisplayTier tier;

  final String label;

  final double size;

  final bool isOwn;

  final bool isSelected;



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

          color: isSelected

              ? const Color(0xFFFF6F00)

              : isOwn

                  ? AppColors.primary

                  : tier.pinBorderColor,

          width: isSelected ? 3.5 : isOwn ? 2.5 : tier.borderWidth,

        ),

        boxShadow: [

          BoxShadow(

            color: tier.pinColor.withValues(alpha: 0.3),

            blurRadius: 6,

            offset: const Offset(0, 2),

          ),

          if (isOwn || isSelected)

            BoxShadow(

              color: (isSelected ? const Color(0xFFFF6F00) : AppColors.primary)

                  .withValues(alpha: 0.3),

              blurRadius: isSelected ? 12 : 8,

              spreadRadius: isSelected ? 2 : 1,

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


