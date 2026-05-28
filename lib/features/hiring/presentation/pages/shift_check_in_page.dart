import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/widgets/app_back_button.dart';

/// 출근 예정일 근태 체크
class ShiftCheckInPage extends StatefulWidget {
  const ShiftCheckInPage({
    super.key,
    required this.application,
  });

  final HiringApplication application;

  @override
  State<ShiftCheckInPage> createState() => _ShiftCheckInPageState();
}

class _ShiftCheckInPageState extends State<ShiftCheckInPage> {
  bool _checkingIn = false;
  bool _loadingLocation = true;
  GeoCoordinate? _currentPosition;
  double? _distanceMeters;
  String? _locationStatus;
  bool _canCheckIn = false;

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationStatus = null;
      _canCheckIn = false;
    });

    try {
      final workplace = widget.application.workplaceCoordinate;
      final relaxed = DeviceLocationService.allowsRelaxedLocation;
      final current = await DeviceLocationService.getCurrentPosition();

      String status;
      double? distance;
      var allowed = false;

      if (workplace == null) {
        status = relaxed
            ? '근무지 좌표 없음 · 데스크톱에서 위치 확인 생략'
            : '근무지 좌표 없음 · GPS 확인 없이 출근 기록 가능';
        allowed = true;
      } else if (relaxed) {
        status =
            '데스크톱 환경 · 근무지 ${workplace.latitude.toStringAsFixed(4)}, '
            '${workplace.longitude.toStringAsFixed(4)} (위치 확인 생략)';
        allowed = true;
      } else if (current == null) {
        status = '위치 권한 또는 GPS를 확인할 수 없습니다';
        allowed = false;
      } else {
        distance = GeoDistance.metersBetween(current, workplace);
        final withinRadius = DeviceLocationService.isWithinCheckInRadius(
          current: current,
          workplace: workplace,
        );
        if (withinRadius) {
          status =
              '근무지 반경 ${GeoDistance.formatDistanceMeters(DeviceLocationService.checkInRadiusMeters)} 이내 '
              '(현재 ${GeoDistance.formatDistanceMeters(distance)})';
          allowed = true;
        } else {
          status =
              '근무지에서 ${GeoDistance.formatDistanceMeters(distance)} 떨어져 있습니다 '
              '(허용 ${GeoDistance.formatDistanceMeters(DeviceLocationService.checkInRadiusMeters)})';
          allowed = false;
        }
      }

      if (!mounted) return;
      setState(() {
        _currentPosition = current;
        _distanceMeters = distance;
        _locationStatus = status;
        _canCheckIn = allowed;
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationStatus = '위치 확인에 실패했습니다';
        _canCheckIn = DeviceLocationService.allowsRelaxedLocation ||
            widget.application.workplaceCoordinate == null;
        _loadingLocation = false;
      });
    }
  }

  Future<void> _checkIn() async {
    if (!_canCheckIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무지 반경 내에서만 출근 기록할 수 있습니다.')),
      );
      return;
    }

    setState(() => _checkingIn = true);
    try {
      final repo = await LocalHiringRepository.create();
      await repo.checkIn(
        widget.application.id,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
      HiringRefresh.markUpdated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '출근이 기록되었습니다. 기업 담당자에게 수수료 결제 안내가 전달됩니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출근 기록에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('출근 체크'),
        actions: [
          IconButton(
            onPressed: _loadingLocation ? null : _refreshLocation,
            tooltip: '위치 새로고침',
            icon: const Icon(Icons.my_location_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.searchBarBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.postTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(app.companyName),
                  const SizedBox(height: 8),
                  Text(app.workSchedule),
                  if (app.workDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '예정일 ${LocalHiringRepository.formatWorkDateFull(app.workDate!)}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.fingerprint_rounded,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 12),
            Text(
              '현재 시각 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _LocationStatusCard(
              loading: _loadingLocation,
              status: _locationStatus,
              distanceMeters: _distanceMeters,
              canCheckIn: _canCheckIn,
            ),
            const Spacer(),
            FilledButton(
              onPressed: (_checkingIn || !_canCheckIn) ? null : _checkIn,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _checkingIn
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '출근 기록하기',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.loading,
    required this.status,
    required this.distanceMeters,
    required this.canCheckIn,
  });

  final bool loading;
  final String? status;
  final double? distanceMeters;
  final bool canCheckIn;

  @override
  Widget build(BuildContext context) {
    final icon = loading
        ? Icons.gps_not_fixed
        : canCheckIn
            ? Icons.gps_fixed
            : Icons.location_off_outlined;
    final color = loading
        ? AppColors.textSecondary
        : canCheckIn
            ? Colors.green.shade700
            : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? '위치 확인 중…' : 'GPS 출근 확인',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  loading ? '근무지와의 거리를 확인하고 있습니다.' : (status ?? ''),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (!loading && distanceMeters != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '거리 ${GeoDistance.formatDistanceMeters(distanceMeters!)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
