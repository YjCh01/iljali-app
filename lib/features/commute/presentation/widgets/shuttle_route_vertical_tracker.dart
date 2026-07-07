import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/utils/shuttle_bus_eta_estimator.dart';
import 'package:map/features/commute/domain/utils/shuttle_bus_timeline_position.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';

/// 공항버스 앱 스타일 — 세로 노선·정류장·실시간 버스 위치
class ShuttleRouteVerticalTracker extends StatelessWidget {
  const ShuttleRouteVerticalTracker({
    super.key,
    required this.route,
    required this.companyName,
    this.busPosition,
    this.myStopId,
    this.onOpenMap,
    this.etaToMyStop,
  });

  final CommuteRoute route;
  final String companyName;
  final GeoCoordinate? busPosition;
  final String? myStopId;
  final VoidCallback? onOpenMap;
  final Duration? etaToMyStop;

  List<CommuteRouteStop> get _stops =>
      ShuttleBusTimelinePosition.orderedStops(route);

  Color get _routeColor => ShuttleRouteColorUtils.parseHex(route.overlayColorHex);

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    final busOnTimeline = ShuttleBusTimelinePosition.resolve(
      stops: stops,
      busPosition: busPosition,
    );
    final schedule = ShuttleBusTimelinePosition.formatScheduleRange(stops);
    final firstLabel = stops.isNotEmpty ? stops.first.label : '';
    final lastLabel = stops.isNotEmpty ? stops.last.label : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RouteHeader(
          companyName: companyName,
          routeName: route.routeName,
          routeColor: _routeColor,
          endpoints: '$firstLabel ↔ $lastLabel',
          schedule: schedule,
          onOpenMap: onOpenMap,
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Column(
              children: [
                for (var i = 0; i < stops.length; i++) ...[
                  _StopTimelineRow(
                    index: i,
                    stop: stops[i],
                    isLast: i == stops.length - 1,
                    isMine: myStopId != null && stops[i].id == myStopId,
                    isNext: busOnTimeline?.nearestStopIndex == i &&
                        busPosition != null,
                    routeColor: _routeColor,
                  ),
                  if (i < stops.length - 1)
                    _SegmentConnector(
                      routeColor: _routeColor,
                      showBus: busOnTimeline != null &&
                          busOnTimeline.segmentIndex == i &&
                          busPosition != null,
                      busFraction: busOnTimeline?.segmentFraction ?? 0,
                      busLabel: route.routeName.trim().isEmpty
                          ? 'BUS'
                          : route.routeName.trim(),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (etaToMyStop != null && busPosition != null) ...[
          const SizedBox(height: 10),
          Text(
            '내 정류장 도착 예상 · ${ShuttleBusEtaEstimator.formatCountdown(etaToMyStop!)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _routeColor,
            ),
          ),
        ] else if (busPosition == null) ...[
          const SizedBox(height: 10),
          Text(
            '운행 중 위치가 공유되면 노선 위에 버스 아이콘이 표시됩니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.companyName,
    required this.routeName,
    required this.routeColor,
    required this.endpoints,
    required this.schedule,
    this.onOpenMap,
  });

  final String companyName;
  final String routeName;
  final Color routeColor;
  final String endpoints;
  final String schedule;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final onPrimary = routeColor.computeLuminance() > 0.55
        ? AppColors.textPrimary
        : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: routeColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            routeName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: onPrimary,
            ),
          ),
          if (endpoints.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              endpoints,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: onPrimary.withValues(alpha: 0.92),
              ),
            ),
          ],
          if (schedule.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '운행 $schedule',
              style: TextStyle(
                fontSize: 12,
                color: onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _HeaderChip(
                icon: Icons.info_outline,
                label: '노선',
                onPrimary: onPrimary,
              ),
              const SizedBox(width: 8),
              if (onOpenMap != null)
                _HeaderChip(
                  icon: Icons.map_outlined,
                  label: '지도',
                  onPrimary: onPrimary,
                  onTap: onOpenMap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onPrimary,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color onPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPrimary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: onPrimary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopTimelineRow extends StatelessWidget {
  const _StopTimelineRow({
    required this.index,
    required this.stop,
    required this.isLast,
    required this.isMine,
    required this.isNext,
    required this.routeColor,
  });

  final int index;
  final CommuteRouteStop stop;
  final bool isLast;
  final bool isMine;
  final bool isNext;
  final Color routeColor;

  String get _timeLabel {
    if (isLast) {
      final arrival = stop.arrivalTime?.trim();
      if (arrival != null && arrival.isNotEmpty) return '도착 $arrival';
    }
    final dep = stop.departureTime?.trim();
    if (dep != null && dep.isNotEmpty) return dep;
    return isLast ? '근무지' : '경유';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _TimelineDot(
            filled: isMine || isNext,
            color: routeColor,
            ring: isMine,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stop.label,
                        style: TextStyle(
                          fontSize: isMine ? 17 : 16,
                          fontWeight:
                              isMine ? FontWeight.w900 : FontWeight.w800,
                          color:
                              isMine ? routeColor : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isMine)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: routeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '내 정류장',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: routeColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${index + 1}번 · $_timeLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentConnector extends StatelessWidget {
  const _SegmentConnector({
    required this.routeColor,
    required this.showBus,
    required this.busFraction,
    required this.busLabel,
  });

  final Color routeColor;
  final bool showBus;
  final double busFraction;
  final String busLabel;

  @override
  Widget build(BuildContext context) {
    const height = 44.0;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Center(
              child: Container(
                width: 4,
                height: height,
                color: routeColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: showBus
                ? Align(
                    alignment: Alignment(
                      -1 + 2 * busFraction.clamp(0.05, 0.95),
                      0,
                    ),
                    child: _BusBadge(
                      routeColor: routeColor,
                      label: busLabel.length > 8
                          ? busLabel.substring(0, 8)
                          : busLabel,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.filled,
    required this.color,
    required this.ring,
  });

  final bool filled;
  final Color color;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ring ? 18 : 14,
      height: ring ? 18 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.white,
        border: Border.all(color: color, width: ring ? 3 : 2),
      ),
    );
  }
}

class _BusBadge extends StatelessWidget {
  const _BusBadge({
    required this.routeColor,
    required this.label,
  });

  final Color routeColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: routeColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: routeColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
