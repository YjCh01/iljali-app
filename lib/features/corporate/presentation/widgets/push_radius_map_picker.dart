import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';

/// 지도에 표시할 비활성(기존) 거점
class PushRadiusMapOverlayPoint {
  const PushRadiusMapOverlayPoint({
    required this.coordinate,
    required this.radiusMeters,
    required this.label,
    required this.pointIndex,
  });

  final GeoCoordinate coordinate;
  final int radiusMeters;
  final String label;
  final int pointIndex;
}

/// 푸시 거점 설정용 지도 피커 (Windows/Web MVP — 추후 Naver Map 연동)
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
  @override
  State<PushRadiusMapPicker> createState() => _PushRadiusMapPickerState();
}

class _PushRadiusMapPickerState extends State<PushRadiusMapPicker> {
  static const _minZoom = 10.0;
  static const _maxZoom = 18.0;
  static const _zoomStep = 0.8;

  late GeoCoordinate _center;
  late double _mapZoom;
  Offset _dragOffset = Offset.zero;
  double _scaleStartZoom = 14;

  @override
  void initState() {
    super.initState();
    _center = widget.center;
    _mapZoom = widget.mapZoom;
  }

  @override
  void didUpdateWidget(PushRadiusMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center) {
      _center = widget.center;
      _dragOffset = Offset.zero;
    }
    if (oldWidget.mapZoom != widget.mapZoom) {
      _mapZoom = widget.mapZoom;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartZoom = _mapZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if ((details.scale - 1.0).abs() > 0.001) {
        _mapZoom = (_scaleStartZoom +
                math.log(details.scale) / math.ln2)
            .clamp(_minZoom, _maxZoom);
      }
      if (widget.centerEditable && details.focalPointDelta != Offset.zero) {
        _applyPanDelta(details.focalPointDelta);
      }
    });
  }

  void _applyPanDelta(Offset delta) {
    _dragOffset += delta;
    final scale = _metersPerPixel();
    _center = GeoCoordinate(
      latitude: _center.latitude - delta.dy * scale / 111320,
      longitude: _center.longitude + delta.dx * scale / (111320 * 0.88),
    );
    widget.onCenterChanged(_center);
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final activeRadiusPx = _radiusPixels(size.shortestSide, widget.radiusMeters);
        final activeLabel = widget.radiusMeters <= 0
            ? '위치만'
            : widget.radiusMeters <= PushPackageCatalog.packagePushRadiusM
                ? '주변'
                : '반경 ${widget.radiusMeters ~/ 1000}km';
        final hasExisting = widget.existingPoints.isNotEmpty;
        final theme = widget.visualTheme ?? PushCreditVisualTheme.basic;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) _onPointerScroll(event);
            },
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                CustomPaint(
                  painter: _MapGridPainter(
                    offset: _dragOffset,
                    zoom: _mapZoom,
                    accentLight: theme.accentLight,
                    gridBackground: theme.mapGridBackground,
                  ),
                ),
                // 기존 거점 — 연한 영역 + 작은 핀
                for (final existing in widget.existingPoints)
                  Center(
                    child: Transform.translate(
                      offset: _geoOffset(existing.coordinate, _center),
                      child: GestureDetector(
                        onTap: widget.onExistingPointTap == null
                            ? null
                            : () => widget.onExistingPointTap!(
                                  existing.pointIndex,
                                ),
                        child: _ExistingPointMarker(
                          radiusPx: _radiusPixels(
                            size.shortestSide,
                            existing.radiusMeters,
                          ),
                          label: existing.label,
                          radiusLabel: existing.radiusMeters <= 0
                              ? '위치만'
                              : existing.radiusMeters <=
                                      PushPackageCatalog.packagePushRadiusM
                                  ? '주변'
                                  : '${existing.radiusMeters ~/ 1000}km',
                          tappable: widget.onExistingPointTap != null,
                          accent: theme.accent,
                        ),
                      ),
                    ),
                  ),
                // 현재 편집 중인 거점 — 강조
                if (activeRadiusPx > 0)
                  Center(
                    child: Container(
                      width: activeRadiusPx * 2,
                      height: activeRadiusPx * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.accent.withValues(alpha: 0.16),
                        border: Border.all(
                          color: theme.accent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_location_alt_rounded,
                        color: theme.accent,
                        size: 40,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.95),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (widget.activePointLabel != null &&
                          widget.activePointLabel!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.accent.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            widget.activePointLabel!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasExisting)
                  Positioned(
                    left: 12,
                    top: 12,
                    right: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.accentLight.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 16,
                              color: theme.accent.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.centerEditable
                                    ? '연한 영역 · 기존 ${widget.existingPoints.length}곳 '
                                        '· 지도 이동 · 두 손가락으로 확대/축소'
                                    : '연한 영역 · 기존 ${widget.existingPoints.length}곳 '
                                        '· 연한 영역을 눌러 다른 구역 편집 · 확대/축소 가능',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  top: hasExisting ? 52 : 12,
                  child: _MapZoomButtons(
                    canZoomIn: _mapZoom < _maxZoom,
                    canZoomOut: _mapZoom > _minZoom,
                    onZoomIn: () => _nudgeZoom(_zoomStep),
                    onZoomOut: () => _nudgeZoom(-_zoomStep),
                    accent: theme.accent,
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '${_center.latitude.toStringAsFixed(5)}, '
                        '${_center.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
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
    required this.radiusLabel,
    this.tappable = false,
    this.accent = AppColors.primary,
  });

  final double radiusPx;
  final String label;
  final String radiusLabel;
  final bool tappable;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (radiusPx > 0)
          SizedBox(
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: accent.withValues(alpha: 0.45),
              size: 26,
            ),
            Container(
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
                '$label · $radiusLabel',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
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
  });

  final Offset offset;
  final double zoom;
  final Color accentLight;
  final Color gridBackground;

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
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.zoom != zoom ||
      oldDelegate.accentLight != accentLight ||
      oldDelegate.gridBackground != gridBackground;
}

GeoCoordinate defaultPushMapCenter() =>
    const GeoCoordinate(latitude: 37.5128, longitude: 127.0471);
