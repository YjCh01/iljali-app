import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/services/nearest_shuttle_stop_service.dart';

/// Hellobus 스타일 — 가까운 탑승장 카드
class NearestShuttleStopCard extends StatefulWidget {
  const NearestShuttleStopCard({
    super.key,
    required this.route,
  });

  final CommuteRoute route;

  @override
  State<NearestShuttleStopCard> createState() => _NearestShuttleStopCardState();
}

class _NearestShuttleStopCardState extends State<NearestShuttleStopCard> {
  bool _loading = true;
  String? _error;
  NearestShuttleStopResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await DeviceLocationService.getCurrentPosition();
      if (pos == null) {
        if (!mounted) return;
        setState(() {
          _error = '위치 권한을 허용하면 가까운 탑승장을 보여드립니다.';
          _loading = false;
        });
        return;
      }
      final result = NearestShuttleStopService.findNearest(
        userPosition: GeoCoordinate(
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
        route: widget.route,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        if (result == null) _error = '정류장 좌표를 확인할 수 없습니다.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '위치를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '가까운 탑승장',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.my_location_outlined),
                tooltip: '위치 새로고침',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            )
          else if (_result != null) ...[
            Text(
              _result!.stop.label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '약 ${GeoDistance.formatDistanceMeters(_result!.distanceMeters)} · '
              '도보 ${_result!.etaHintMinutes}분',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_result!.stop.departureTime != null) ...[
              const SizedBox(height: 4),
              Text(
                '탑승 ${_result!.stop.departureTime}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
