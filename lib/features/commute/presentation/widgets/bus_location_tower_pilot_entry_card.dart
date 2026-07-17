import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_service.dart';
import 'package:map/core/pilot/bus_location_tower_pilot_status.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 지정된 구직자에게만 — 실시간 버스 관제 파일럿 진입 카드
class BusLocationTowerPilotEntryCard extends StatefulWidget {
  const BusLocationTowerPilotEntryCard({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<BusLocationTowerPilotEntryCard> createState() =>
      _BusLocationTowerPilotEntryCardState();
}

class _BusLocationTowerPilotEntryCardState
    extends State<BusLocationTowerPilotEntryCard> {
  late Future<BusLocationTowerPilotStatus> _future =
      BusLocationTowerPilotService.refresh();

  Future<void> _reload() async {
    setState(() {
      _future = BusLocationTowerPilotService.refresh(force: true);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BusLocationTowerPilotStatus>(
      future: _future,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || !status.shouldShowEntry) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(bottom: widget.compact ? 12 : 16),
          child: CorporateSurfaceCard(
            onTap: () async {
              final route = status.isDesignated
                  ? AppRoutes.seekerBusLocationTowerPilot
                  : AppRoutes.seekerMyBus;
              await Navigator.of(context).pushNamed(route);
              if (mounted) await _reload();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.isDesignated
                                ? '버스위치 공유 담당 · 오늘 위치 공유'
                                : '오늘 탑승 셔틀 · 실시간 위치 확인',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ],
                ),
                if (!widget.compact && status.message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    status.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      label: status.locationConsentGranted
                          ? '위치 동의 완료'
                          : '위치 동의 필요',
                      ok: status.locationConsentGranted,
                    ),
                    _Chip(
                      label: status.hasLiveLocation ? '위치 공유 중' : '위치 대기 중',
                      ok: status.hasLiveLocation,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.primaryLight.withValues(alpha: 0.22)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ok ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
