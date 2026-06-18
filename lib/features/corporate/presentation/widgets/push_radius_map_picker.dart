import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_unavailable_placeholder.dart';

/// 지도에 표시할 비활성(기존) 거점
class PushRadiusMapOverlayPoint {
  const PushRadiusMapOverlayPoint({
    required this.coordinate,
    required this.radiusMeters,
    required this.label,
    required this.pointIndex,
    this.visualTheme,
    this.draft = false,
  });

  final GeoCoordinate coordinate;
  final int radiusMeters;
  final String label;
  final int pointIndex;
  final PushCreditVisualTheme? visualTheme;
  /// 미노출(저장만) 정류장 — 지도에서 흐리게
  final bool draft;
}

/// 셔틀 노선 경로 — 복수 노선 지원
class PushRadiusMapPolyline {
  const PushRadiusMapPolyline({
    required this.points,
    required this.color,
  });

  final List<GeoCoordinate> points;
  final Color color;
}

/// PUSH·셔틀 거점/정류장 지도 — Naver Map(모바일) + MVP 그리드(Windows/Web)
class PushRadiusMapPicker extends StatefulWidget {
  const PushRadiusMapPicker({
    super.key,
    required this.center,
    required this.radiusMeters,
    required this.onCenterChanged,
    this.existingPoints = const [],
    this.activePointLabel,
    this.mapZoom = 14,
    this.centerEditable = true,
    this.onExistingPointTap,
    this.visualTheme,
    /// 통근버스·셔틀 정류장 — 반경 0일 때 「위치만」 뱃지 숨김
    this.hideZeroRadiusLabel = false,
    this.polylinePoints = const [],
    this.polylineColor,
    this.polylines = const [],
  });

  final GeoCoordinate center;
  final int radiusMeters;
  final ValueChanged<GeoCoordinate> onCenterChanged;
  /// 현재 편집 중인 거점을 제외한 기존 거점들
  final List<PushRadiusMapOverlayPoint> existingPoints;
  final String? activePointLabel;
  final double mapZoom;
  /// false면 지도 드래그로 거점 이동 불가 (기본 거점 등)
  final bool centerEditable;
  final ValueChanged<int>? onExistingPointTap;
  final PushCreditVisualTheme? visualTheme;
  final bool hideZeroRadiusLabel;
  /// 셔틀 노선 경로 — 활성화된 정류장 3곳 이상일 때
  final List<GeoCoordinate> polylinePoints;
  final Color? polylineColor;
  /// 복수 노선 경로 (지정 시 [polylinePoints]보다 우선)
  final List<PushRadiusMapPolyline> polylines;
  @override
  State<PushRadiusMapPicker> createState() => _PushRadiusMapPickerState();
}

class _PushRadiusMapPickerState extends State<PushRadiusMapPicker> {
  static const _minZoom = 10.0;
  static const _maxZoom = 18.0;
  static const _zoomStep = 0.8;

  late GeoCoordinate _center;
  late GeoCoordinate _viewCenter;
  late double _mapZoom;
  Offset _dragOffset = Offset.zero;
  double _scaleStartZoom = 14;
  bool _isDragging = false;

  GeoCoordinate get _renderCenter =>
      widget.centerEditable ? _center : _viewCenter;

  @override
  void initState() {
    super.initState();
    _center = widget.center;
    _viewCenter = widget.center;
    _mapZoom = widget.mapZoom;
  }

  @override
  void didUpdateWidget(PushRadiusMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.center != widget.center) {
      _center = widget.center;
      _viewCenter = widget.center;
      _dragOffset = Offset.zero;
    }
    if (oldWidget.mapZoom != widget.mapZoom) {
      _mapZoom = widget.mapZoom;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartZoom = _mapZoom;
    _isDragging = true;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isDragging = false;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if ((details.scale - 1.0).abs() > 0.001) {
        _mapZoom = (_scaleStartZoom +
                math.log(details.scale) / math.ln2)
            .clamp(_minZoom, _maxZoom);
      }
      if (details.focalPointDelta != Offset.zero) {
        _applyPanDelta(details.focalPointDelta);
      }
    });
  }

  void _applyPanDelta(Offset delta) {
    _dragOffset += delta;
    final scale = _metersPerPixel();
    final next = GeoCoordinate(
      latitude: _renderCenter.latitude - delta.dy * scale / 111320,
      longitude: _renderCenter.longitude + delta.dx * scale / (111320 * 0.88),
    );
    if (widget.centerEditable) {
      _center = next;
      _viewCenter = next;
      widget.onCenterChanged(_center);
    } else {
      _viewCenter = next;
    }
  }

  void _nudgeZoom(double delta) {
    setState(() {
      _mapZoom = (_mapZoom + delta).clamp(_minZoom, _maxZoom);
    });
  }

  void _onPointerScroll(PointerScrollEvent event) {
    if (event.scrollDelta.dy == 0) return;
    _nudgeZoom(-event.scrollDelta.dy.sign * _zoomStep);
  }

  double _metersPerPixel() {
    return 156543.03392 * (1 / (1 << _mapZoom.round().clamp(10, 18))) / 2.5;
  }

  double _radiusPixels(double maxSide, int radiusMeters) {
    if (radiusMeters <= 0) return 0;
    final metersPerPixel = _metersPerPixel();
    if (metersPerPixel <= 0) return 40;
    return (radiusMeters / metersPerPixel).clamp(24, maxSide * 0.45);
  }

  Offset _geoOffset(GeoCoordinate target, GeoCoordinate viewCenter) {
    final mpp = _metersPerPixel();
    final dLat = target.latitude - viewCenter.latitude;
    final dLng = target.longitude - viewCenter.longitude;
    final dx = dLng * 111320 * 0.88 / mpp;
    final dy = -dLat * 111320 / mpp;
    return Offset(dx, dy);
  }

  /// null이면 반경 뱃지·라벨 접미사를 표시하지 않음
  String? _radiusLabelFor(int radiusMeters) {
    if (radiusMeters <= 0) {
      return widget.hideZeroRadiusLabel ? null : '위치만';
    }
    if (radiusMeters <= PushPackageCatalog.packagePushRadiusM) {
      return '주변';
    }
    return '반경 ${radiusMeters ~/ 1000}km';
  }

  bool get _showsCenterPin =>
      widget.centerEditable ||
      widget.radiusMeters > 0 ||
      (widget.existingPoints.isEmpty && widget.polylines.isEmpty);

  List<PushRadiusMapPolyline> get _effectivePolylines {
    if (widget.polylines.isNotEmpty) return widget.polylines;
    if (widget.polylinePoints.length >= 2) {
      return [
        PushRadiusMapPolyline(
          points: widget.polylinePoints,
          color: widget.polylineColor ?? AppColors.primary,
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (NaverMapPlatform.shouldShowMap) {
      return _PushRadiusNaverMapPicker(
        center: widget.center,
        radiusMeters: widget.radiusMeters,
        onCenterChanged: widget.onCenterChanged,
        existingPoints: widget.existingPoints,
        activePointLabel: widget.activePointLabel,
        mapZoom: widget.mapZoom,
        centerEditable: widget.centerEditable,
        onExistingPointTap: widget.onExistingPointTap,
        visualTheme: widget.visualTheme,
        hideZeroRadiusLabel: widget.hideZeroRadiusLabel,
        polylinePoints: widget.polylinePoints,
        polylineColor: widget.polylineColor,
        polylines: _effectivePolylines,
        showsCenterPin: _showsCenterPin,
        radiusLabelFor: _radiusLabelFor,
      );
    }

    return _buildMockMap(context);
  }

  Widget _buildMockMap(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final activeRadiusPx = _radiusPixels(size.shortestSide, widget.radiusMeters);
        final hasExisting = widget.existingPoints.isNotEmpty;
        final activeTheme = widget.visualTheme ?? PushCreditVisualTheme.basic;
        // 다중 지역일 때 지도 배경·컨트롤은 고정 — 선택 중인 거점만 activeTheme 색
        final chromeTheme = hasExisting
            ? PushCreditVisualTheme.package
            : activeTheme;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) _onPointerScroll(event);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                CustomPaint(
                  painter: _MapGridPainter(
                    offset: _dragOffset,
                    zoom: _mapZoom,
                    accentLight: chromeTheme.accentLight,
                    gridBackground: chromeTheme.mapGridBackground,
                    polylinePoints: widget.polylinePoints,
                    polylineColor: widget.polylineColor ?? activeTheme.accent,
                    polylines: _effectivePolylines,
                    viewCenter: _renderCenter,
                    geoOffset: _geoOffset,
                  ),
                ),
                // 기존 거점 — 연한 영역 + 작은 핀
                for (final existing in widget.existingPoints)
                  Center(
                    child: Transform.translate(
                      offset: _geoOffset(existing.coordinate, _renderCenter),
                      child: _ExistingPointMarker(
                        radiusPx: _radiusPixels(
                          size.shortestSide,
                          existing.radiusMeters,
                        ),
                        label: existing.label,
                        tappable: widget.onExistingPointTap != null,
                        onTap: widget.onExistingPointTap == null
                            ? null
                            : () => widget.onExistingPointTap!(
                                  existing.pointIndex,
                                ),
                        accent: (existing.visualTheme ??
                                PushCreditVisualTheme.forRecruitPoint(
                                  existing.pointIndex,
                                ))
                            .accent,
                        muted: existing.draft,
                      ),
                    ),
                  ),
                // 현재 편집 중인 거점 — 강조 (시각만, 터치는 아래 지도 제스처로)
                if (activeRadiusPx > 0)
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        width: activeRadiusPx * 2,
                        height: activeRadiusPx * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeTheme.accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: activeTheme.accent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showsCenterPin)
                  Center(
                    child: IgnorePointer(
                      child: _CenterPinBadge(
                        accent: activeTheme.accent,
                        pointLabel: widget.activePointLabel,
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _MapZoomButtons(
                    canZoomIn: _mapZoom < _maxZoom,
                    canZoomOut: _mapZoom > _minZoom,
                    onZoomIn: () => _nudgeZoom(_zoomStep),
                    onZoomOut: () => _nudgeZoom(-_zoomStep),
                    accent: chromeTheme.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

class _MapZoomButtons extends StatelessWidget {
  const _MapZoomButtons({
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.accent,
  });

  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      color: AppColors.surface.withValues(alpha: 0.96),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: canZoomIn ? onZoomIn : null,
            icon: Icon(Icons.add_rounded, size: 20, color: accent),
            tooltip: '확대',
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: canZoomOut ? onZoomOut : null,
            icon: Icon(Icons.remove_rounded, size: 20, color: accent),
            tooltip: '축소',
          ),
        ],
      ),
    );
  }
}

class _ExistingPointMarker extends StatelessWidget {
  const _ExistingPointMarker({
    required this.radiusPx,
    required this.label,
    this.tappable = false,
    this.onTap,
    this.accent = AppColors.primary,
    this.muted = false,
  });

  final double radiusPx;
  final String label;
  final bool tappable;
  final VoidCallback? onTap;
  final Color accent;
  final bool muted;

  static const _tapTargetSize = 52.0;

  @override
  Widget build(BuildContext context) {
    final pinIcon = Icon(
      Icons.location_on_outlined,
      color: (muted ? AppColors.textSecondary : accent).withValues(
        alpha: muted ? 0.45 : 0.75,
      ),
      size: 26,
    );
    final pinLabel = Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.searchBarBorder,
        ),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (radiusPx > 0)
          IgnorePointer(
            child: SizedBox(
              width: radiusPx * 2,
              height: radiusPx * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(
                    alpha: tappable ? 0.1 : 0.06,
                  ),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: tappable ? 0.42 : 0.28,
                    ),
                    width: tappable ? 2 : 1.5,
                  ),
                ),
              ),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tappable && onTap != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(_tapTargetSize / 2),
                  child: SizedBox(
                    width: _tapTargetSize,
                    height: _tapTargetSize,
                    child: Center(child: pinIcon),
                  ),
                ),
              )
            else
              IgnorePointer(child: pinIcon),
            IgnorePointer(child: pinLabel),
          ],
        ),
      ],
    );
  }
}
/// 반경 슬라이더 — 플랜 허용 km만 선택 (discrete index)
class PushRadiusKmSlider extends StatelessWidget {
  const PushRadiusKmSlider({
    super.key,
    required this.selectedKm,
    required this.onChanged,
    this.allowedKmSteps,
    this.accentColor,
    this.suppressCenterLabel = false,
  });

  final int selectedKm;
  final ValueChanged<int> onChanged;
  final List<int>? allowedKmSteps;
  final Color? accentColor;
  final bool suppressCenterLabel;

  List<int> get _steps {
    final steps = allowedKmSteps ?? PushRadiusOptions.sliderKmSteps;
    if (steps.isEmpty) return const [1];
    return steps;
  }

  int get _safeIndex {
    final idx = _steps.indexOf(selectedKm);
    if (idx >= 0) return idx;
    // 허용 목록에 없으면 가장 가까운 단계로 스냅
    var nearest = 0;
    var minDiff = (selectedKm - _steps.first).abs();
    for (var i = 1; i < _steps.length; i++) {
      final diff = (selectedKm - _steps[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = i;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final maxIndex = steps.length - 1;
    final currentIndex = _safeIndex.clamp(0, maxIndex);
    final accent = accentColor ?? AppColors.primary;

    if (maxIndex == 0) {
      if (suppressCenterLabel) {
        return const SizedBox.shrink();
      }
      final radiusLabel = steps.first <= 1 ? '주변' : '반경 ${steps.first}km';
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            radiusLabel,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: currentIndex > 0
                  ? () => onChanged(steps[currentIndex - 1])
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  overlayColor: accent.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: currentIndex.toDouble(),
                  min: 0,
                  max: maxIndex.toDouble(),
                  divisions: maxIndex,
                  label: '${steps[currentIndex]}km',
                  onChanged: (value) {
                    final index = value.round().clamp(0, maxIndex);
                    onChanged(steps[index]);
                  },
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: currentIndex < maxIndex
                  ? () => onChanged(steps[currentIndex + 1])
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps
              .map(
                (km) => Text(
                  '${km}km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selectedKm == km
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selectedKm == km
                        ? accent
                        : AppColors.textSecondary,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter({
    required this.offset,
    required this.zoom,
    this.accentLight = AppColors.primaryLight,
    this.gridBackground = const Color(0xFFE8E4F8),
    this.polylinePoints = const [],
    this.polylineColor = AppColors.primary,
    this.polylines = const [],
    required this.viewCenter,
    required this.geoOffset,
  });

  final Offset offset;
  final double zoom;
  final Color accentLight;
  final Color gridBackground;
  final List<GeoCoordinate> polylinePoints;
  final Color polylineColor;
  final List<PushRadiusMapPolyline> polylines;
  final GeoCoordinate viewCenter;
  final Offset Function(GeoCoordinate target, GeoCoordinate viewCenter) geoOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = gridBackground;
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = accentLight.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    final step = 40 + zoom;
    for (var x = offset.dx % step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = offset.dy % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.42),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.28, size.height),
      road,
    );

    if (polylines.isNotEmpty) {
      for (var i = 0; i < polylines.length; i++) {
        _drawPolyline(canvas, size, polylines[i]);
      }
    } else if (polylinePoints.length >= 2) {
      _drawPolyline(
        canvas,
        size,
        PushRadiusMapPolyline(points: polylinePoints, color: polylineColor),
      );
    }
  }

  void _drawPolyline(Canvas canvas, Size size, PushRadiusMapPolyline line) {
    if (line.points.length < 2) return;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (var i = 0; i < line.points.length; i++) {
      final point = center + geoOffset(line.points[i], viewCenter);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line.color.withValues(alpha: 0.35)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line.color
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.zoom != zoom ||
      oldDelegate.accentLight != accentLight ||
      oldDelegate.gridBackground != gridBackground ||
      oldDelegate.polylinePoints != polylinePoints ||
      oldDelegate.polylineColor != polylineColor ||
      oldDelegate.polylines != polylines ||
      oldDelegate.viewCenter != viewCenter;
}

GeoCoordinate defaultPushMapCenter() =>
    const GeoCoordinate(latitude: 37.5128, longitude: 127.0471);

class _CenterPinBadge extends StatelessWidget {
  const _CenterPinBadge({
    required this.accent,
    this.pointLabel,
  });

  final Color accent;
  final String? pointLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on_rounded,
          color: accent,
          size: 40,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.95),
              blurRadius: 8,
            ),
          ],
        ),
        if (pointLabel != null && pointLabel!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              pointLabel!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Naver Map 기반 PUSH·셔틀 지도 (Android/iOS)
class _PushRadiusNaverMapPicker extends StatefulWidget {
  const _PushRadiusNaverMapPicker({
    required this.center,
    required this.radiusMeters,
    required this.onCenterChanged,
    required this.existingPoints,
    required this.activePointLabel,
    required this.mapZoom,
    required this.centerEditable,
    required this.onExistingPointTap,
    required this.visualTheme,
    required this.hideZeroRadiusLabel,
    required this.polylinePoints,
    required this.polylineColor,
    required this.polylines,
    required this.showsCenterPin,
    required this.radiusLabelFor,
  });

  final GeoCoordinate center;
  final int radiusMeters;
  final ValueChanged<GeoCoordinate> onCenterChanged;
  final List<PushRadiusMapOverlayPoint> existingPoints;
  final String? activePointLabel;
  final double mapZoom;
  final bool centerEditable;
  final ValueChanged<int>? onExistingPointTap;
  final PushCreditVisualTheme? visualTheme;
  final bool hideZeroRadiusLabel;
  final List<GeoCoordinate> polylinePoints;
  final Color? polylineColor;
  final List<PushRadiusMapPolyline> polylines;
  final bool showsCenterPin;
  final String? Function(int radiusMeters) radiusLabelFor;

  @override
  State<_PushRadiusNaverMapPicker> createState() =>
      _PushRadiusNaverMapPickerState();
}

class _PushRadiusNaverMapPickerState extends State<_PushRadiusNaverMapPicker> {
  static const _minZoom = 10.0;
  static const _maxZoom = 18.0;
  static const _zoomStep = 0.8;

  NaverMapController? _controller;
  GeoCoordinate? _lastReportedCenter;
  bool _mapReady = false;

  PushCreditVisualTheme get _activeTheme =>
      widget.visualTheme ?? PushCreditVisualTheme.basic;

  PushCreditVisualTheme get _chromeTheme => widget.existingPoints.isNotEmpty
      ? PushCreditVisualTheme.package
      : _activeTheme;

  @override
  void didUpdateWidget(_PushRadiusNaverMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    final centerChanged = oldWidget.center != widget.center;
    final overlaysChanged = oldWidget.existingPoints != widget.existingPoints ||
        oldWidget.radiusMeters != widget.radiusMeters ||
        oldWidget.polylinePoints != widget.polylinePoints ||
        oldWidget.polylineColor != widget.polylineColor ||
        oldWidget.polylines != widget.polylines ||
        oldWidget.visualTheme != widget.visualTheme;

    if (overlaysChanged) {
      _syncOverlays();
    }

    if (centerChanged && widget.centerEditable) {
      _moveCameraTo(widget.center, animate: false);
      _lastReportedCenter = widget.center;
    } else if (centerChanged && !widget.centerEditable) {
      _moveCameraTo(widget.center, animate: true);
    }
  }

  Future<void> _moveCameraTo(
    GeoCoordinate coordinate, {
    required bool animate,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    final update = NCameraUpdate.withParams(
      target: NLatLng(coordinate.latitude, coordinate.longitude),
      zoom: widget.mapZoom,
    );
    if (!animate) {
      update.setAnimation(animation: NCameraAnimation.none);
    }
    await controller.updateCamera(update);
  }

  Future<void> _handleMapReady(NaverMapController controller) async {
    _controller = controller;
    _lastReportedCenter = widget.center;
    await _syncOverlays();
    if (!mounted) return;
    setState(() => _mapReady = true);
  }

  Future<void> _handleCameraIdle() async {
    if (!widget.centerEditable) return;
    final controller = _controller;
    if (controller == null) return;

    final camera = await controller.getCameraPosition();
    final next = GeoCoordinate(
      latitude: camera.target.latitude,
      longitude: camera.target.longitude,
    );
    if (_lastReportedCenter != null &&
        _sameCoordinate(_lastReportedCenter!, next)) {
      return;
    }
    _lastReportedCenter = next;
    widget.onCenterChanged(next);
    await _syncOverlays();
  }

  bool _sameCoordinate(GeoCoordinate a, GeoCoordinate b) {
    return (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }

  Future<void> _nudgeZoom(double delta) async {
    final controller = _controller;
    if (controller == null) return;
    final camera = await controller.getCameraPosition();
    final nextZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
    if (nextZoom == camera.zoom) return;
    final update = NCameraUpdate.withParams(zoom: nextZoom);
    update.setAnimation(
      animation: NCameraAnimation.easing,
      duration: const Duration(milliseconds: 200),
    );
    await controller.updateCamera(update);
  }

  Future<void> _syncOverlays() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.clearOverlays(type: NOverlayType.circleOverlay);
    await controller.clearOverlays(type: NOverlayType.marker);
    await controller.clearOverlays(type: NOverlayType.pathOverlay);

    final overlays = _buildOverlays();
    if (overlays.isNotEmpty) {
      controller.addOverlayAll(overlays);
    }
  }

  Set<NAddableOverlay> _buildOverlays() {
    final overlays = <NAddableOverlay>{};
    final activeTheme = _activeTheme;

    for (final point in widget.existingPoints) {
      final accent = (point.visualTheme ??
              PushCreditVisualTheme.forRecruitPoint(point.pointIndex))
          .accent;
      final alpha = point.draft ? 0.45 : 1.0;
      final tint = accent.withValues(alpha: alpha);

      if (point.radiusMeters > 0) {
        overlays.add(
          NCircleOverlay(
            id: 'push_existing_circle_${point.pointIndex}',
            center: NLatLng(
              point.coordinate.latitude,
              point.coordinate.longitude,
            ),
            radius: point.radiusMeters.toDouble(),
            color: tint.withValues(alpha: 0.12),
            outlineColor: tint.withValues(alpha: 0.55),
            outlineWidth: 2,
          ),
        );
      }

      final captionText = point.label;

      final marker = NMarker(
        id: 'push_existing_marker_${point.pointIndex}',
        position: NLatLng(
          point.coordinate.latitude,
          point.coordinate.longitude,
        ),
        iconTintColor: tint,
        size: const Size(28, 28),
        caption: NOverlayCaption(
          text: captionText,
          color: Colors.white,
          haloColor: tint.withValues(alpha: 0.85),
          textSize: 11,
        ),
        isHideCollidedCaptions: true,
      );
      if (widget.onExistingPointTap != null) {
        final index = point.pointIndex;
        marker.setOnTapListener((_) => widget.onExistingPointTap!(index));
      }
      overlays.add(marker);
    }

    if (widget.radiusMeters > 0) {
      overlays.add(
        NCircleOverlay(
          id: 'push_active_circle',
          center: NLatLng(widget.center.latitude, widget.center.longitude),
          radius: widget.radiusMeters.toDouble(),
          color: activeTheme.accent.withValues(alpha: 0.16),
          outlineColor: activeTheme.accent,
          outlineWidth: 2.5,
        ),
      );
    }

    final routePolylines = widget.polylines.isNotEmpty
        ? widget.polylines
        : (widget.polylinePoints.length >= 2
            ? [
                PushRadiusMapPolyline(
                  points: widget.polylinePoints,
                  color: widget.polylineColor ?? activeTheme.accent,
                ),
              ]
            : const <PushRadiusMapPolyline>[]);

    for (var i = 0; i < routePolylines.length; i++) {
      final line = routePolylines[i];
      if (line.points.length < 2) continue;
      overlays.add(
        NPathOverlay(
          id: 'push_route_polyline_$i',
          coords: line.points
              .map((c) => NLatLng(c.latitude, c.longitude))
              .toList(),
          width: 5,
          color: line.color,
          outlineColor: Colors.white,
          outlineWidth: 2,
        ),
      );
    }

    return overlays;
  }

  @override
  Widget build(BuildContext context) {
    if (!NaverMapPlatform.shouldShowMap) {
      return const MapUnavailablePlaceholder();
    }

    final safeAreaPadding = MediaQuery.paddingOf(context);
    final chromeTheme = _chromeTheme;
    final activeTheme = _activeTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NaverMap(
            forceGesture: true,
            options: NaverMapViewOptions(
              contentPadding: safeAreaPadding,
              initialCameraPosition: NCameraPosition(
                target: NLatLng(widget.center.latitude, widget.center.longitude),
                zoom: widget.mapZoom,
              ),
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              scaleBarEnable: false,
              locationButtonEnable: false,
              compassEnable: false,
              rotationGesturesEnable: false,
              tiltGesturesEnable: false,
            ),
            onMapReady: _handleMapReady,
            onCameraIdle: _handleCameraIdle,
          ),
          if (widget.showsCenterPin)
            Center(
              child: IgnorePointer(
                child: _CenterPinBadge(
                  accent: activeTheme.accent,
                  pointLabel: widget.activePointLabel,
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: _MapZoomButtons(
              canZoomIn: _mapReady,
              canZoomOut: _mapReady,
              onZoomIn: () => _nudgeZoom(_zoomStep),
              onZoomOut: () => _nudgeZoom(-_zoomStep),
              accent: chromeTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
